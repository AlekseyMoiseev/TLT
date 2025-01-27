#!/bin/bash

# Config

serverIp=$(hostname -I | cut -d' ' -f1)
#serverIp="192.168.33.217"

maxNumberAttempts="5"

postgresPort="5432"
postgresUser="postgres"
postgresNewPassword="4Uex6Bb9"
postgresTpsDb="treatmentplanningdb"
postgresIcdDb="icddb"

minioConfig="/etc/default/minio"
minioAlias="tps"
minioCliPort="9000"
minioIp=$serverIp
minioBucket="appointment"
minioSystemUser="minio-user"
minioUser="minioadmin"
minioPassword="minioadmin"
minioVolumes="/opt/minio"
minioClientDir="/opt/minio-client"
minioOpts="--console-address :9001"
minioNotifyWebhookEnable="on"
minioNotifyWebhookEndpoint="http://localhost:5180/BucketNotifications"

tpsDir="/opt/tps"
logFile="$tpsDir/install.log"
tpsSslDir="$tpsDir/tps/ssl"
tpsBackendConfig="$tpsDir/tps/backend/.env"
icdConfig="$tpsDir/tps/icd/.env"
tpsMinioConfig="$tpsDir/tps/cors/minio.conf"
tpsComposeFile="$tpsDir/tps/docker-compose.yml"
montecarloComposeFile="$tpsDir/tps/docker-compose-montecarlo.yml"
pencilbeamComposeFile="$tpsDir/tps/docker-compose-pencilbeam.yml"
orthancComposeFile="$tpsDir/PACS/docker-compose.yml"
tpsGitUrl="https://tfs.sibedge.com/SibEDGE_Collection/TreatmentPlanningSystem/_git/TpsLauncher"
tpsGitEmail="tps@tps.ru"
tpsGitUserName="TPS"

dockerGitlabRegistry="nexus.sibedge.com"

sslC="RU"
sslST="Moscow region"
sslL="Moscow"
sslO="RT7 LLC"
sslOU="TPS"
sslDays="1825"
sslCN=$serverIp




# Function

# Print template message to console
function printTaskMessage {
    # Number of steps
    STEPS=9
    i=$((i+1))
    echo -e "[ $i/$STEPS ] $1 ******************************************************************"
    echo -e "[ $i/$STEPS ] $1 ******************************************************************" >> $logFile
}

function printSuccessMessage {
    echo -e "\033[32m[DONE] $1\033[0m"
}

function printWarningMessage {
    echo -e "\033[33m[WARN] $1\033[0m"
}

function printErrorMessage {
    echo -e "\033[31m[ERROR] $1. See log file $logFile\033[0m"
    exit
}

function printSuccess {
    echo -e "\033[32m$1\033[0m"
}

# Функция для установки переменных окружения PostgreSQL
setPostgresEnv() {
    export PGHOST=$serverIp
    export PGPORT=$postgresPort
    export PGUSER=$postgresUser
    export PGPASSWORD=$postgresNewPassword
    printSuccessMessage "PostgreSQL environment variables set."
}

# Repository update
function aptUpdate {
    apt-get -qq -o Dpkg::Progress-Fancy="1" update
    if [ $? -ne 0 ]; then
            printErrorMessage "repository update failure"
    else
            printSuccessMessage "repository update"
    fi
}

# SSH
function sshDeploy {
    # Check if ssh server is installed
    dpkg -s openssh-server >> $logFile 2>&1
    if [ $? -ne 0 ]; then
        apt-get -qq -o Dpkg::Progress-Fancy="1" install openssh-server
        if [ $? -ne 0 ]; then
                printWarningMessage "service installation failure"
        else
                printSuccessMessage "service installation"
        fi

        ufw allow ssh >> $logFile
        if [ $? -ne 0 ]; then
                printWarningMessage "fail adding firewall rule"
        else
                printSuccessMessage "add firewall rule for SSH"
        fi
    else
        printWarningMessage "ssh server is already installed, skip this step"
    fi
}


# curl
function curlInstall {
    # Check if curl is installed
    dpkg -s curl >> $logFile 2>&1
    if [ $? -ne 0 ]; then
        apt-get -qq -o Dpkg::Progress-Fancy="1" install curl
        if [ $? -ne 0 ]; then
                printErrorMessage "curl installation failure"
        else
                printSuccessMessage "curl install"
        fi
    else
        printWarningMessage "curl is already installed, skip this step"
    fi
}


# Postgresql
function postgresqlDeploy {
    # Check if postgresql is installed
    dpkg -s postgresql >> $logFile 2>&1
    if [ $? -ne 0 ]; then
        apt-get -qq -o Dpkg::Progress-Fancy="1" install postgresql
        if [ $? -ne 0 ]; then
                printErrorMessage "postgresql installation failure"
        else
                printSuccessMessage "postgresql install"
        fi

        # Postgres health check
        max_attempts=3
        attempt=1

        while [ $attempt -le $max_attempts ]; do
            if pg_isready > /dev/null 2>&1; then
                printSuccessMessage "postgres is running after $attempt attempts"
                break
            else
                printWarningMessage "attempt $attempt: Postgres is not running"
                systemctl start postgresql
            fi
            attempt=$((attempt + 1))
            sleep 3
            if [ $attempt -gt $max_attempts ]; then
                printErrorMessage "postgres not running after $max_attempts attempts"
            fi
        done


        # Get config file
        postgresqlConfig=$(cd /tmp && sudo -u $postgresUser psql -t -P format=unaligned -c 'SHOW config_file')
        if [ -e $postgresqlConfig ]
        then
            sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $postgresqlConfig
            printSuccessMessage "create postgresql main config"
        else
            printErrorMessage "postgresql not install or config $postgresqlConfig file does not exist" >> $logFile
        fi

        # Get hba file
        postgresqlHbaConfig=$(cd /tmp && sudo -u $postgresUser psql -t -P format=unaligned -c 'SHOW hba_file')
        if [ -e $postgresqlHbaConfig ]
        then
            sed -i "s/local   all             postgres                                peer/local   all             postgres                                md5/" $postgresqlHbaConfig
            echo "host all all 0.0.0.0/0 md5" >> $postgresqlHbaConfig
            echo "host all all ::/0 md5" >> $postgresqlHbaConfig
            printSuccessMessage "create postgresql hba config"
        else
            printErrorMessage "postgresql not install or hba config $postgresqlHbaConfig file does not exist" >> $logFile
        fi

        # Prepare user
        cd /tmp && sudo -u $postgresUser psql -c "ALTER USER $postgresUser with encrypted password '$postgresNewPassword';" >> $logFile
        
        systemctl restart postgresql >> $logFile
        if [ $? -ne 0 ]; then
            printWarningMessage "postgresql restart failure"
        else
            printSuccessMessage "postgresql applying new settings"
        fi
        setPostgresEnv
        # Prepare DB
        createdb $postgresTpsDb >> $logFile
        createdb $postgresIcdDb >> $logFile
    else
        printWarningMessage "postgresql is already installed, skip this step"
    fi
}

# Minio
function minioDeploy {
    # Check if minio is installed
    dpkg -s minio >> $logFile 2>&1
    if [ $? -ne 0 ]; then
        # Download minio server
        curl --progress-bar https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20221212192727.0.0_amd64.deb  -o /tmp/minio.deb
        if [ $? -ne 0 ]; then
            printErrorMessage "server download failure"
        else
            printSuccessMessage "server download"
        fi

        # Install minio server
        dpkg -i /tmp/minio.deb >> $logFile
        if [ $? -ne 0 ]; then
            printErrorMessage "server install failure"
        else
            printSuccessMessage "server install"
        fi

        # Add minio user 
        id $minioSystemUser >> $logFile 2>&1
        if [ $? -ne 0 ]; then
            useradd -M -r -U $minioSystemUser >> $logFile
            printSuccessMessage "user $minioSystemUser added"
        else
            printWarningMessage "user $minioSystemUser already added, skip this step"
        fi

        # Create minio volumes
        if [ ! -d "$minioVolumes" ]; then
            mkdir $minioVolumes >> $logFile
            if [ $? -ne 0 ]; then
                printErrorMessage "create volumes dir failure: $minioVolumes"
            else
                printSuccessMessage "create volumes dir: $minioVolumes"
                chown $minioSystemUser:$minioSystemUser $minioVolumes >> $logFile
            fi
        else
            printWarningMessage "volumes dir $minioVolumes already exist, skip this step"
        fi

        # Create config file
        if [ ! -f $minioConfig ]; then
            cat <<EOF > $minioConfig
MINIO_VOLUMES="$minioVolumes"
MINIO_OPTS="$minioOpts"
MINIO_ROOT_USER=$minioUser
MINIO_ROOT_PASSWORD=$minioPassword
MINIO_NOTIFY_WEBHOOK_ENABLE=$minioNotifyWebhookEnable
MINIO_NOTIFY_WEBHOOK_ENDPOINT=$minioNotifyWebhookEndpoint
EOF
            if [ $? -ne 0 ]; then
                printErrorMessage "create config file failure"
            else
                printSuccessMessage "create config file"
            fi
        else
            printWarningMessage "minio config file $minioConfig already exist, skip this step"
        fi

        # Enable minio service
        systemctl enable minio 2>/dev/null >> $logFile

        # Restart minio service
        systemctl restart minio >> $logFile
        if [ $? -ne 0 ]; then
            printErrorMessage "service restart failure"
        else
            printSuccessMessage "restart minio and apply new settings"
        fi

        # Delete minio deb package
        [ -f "/tmp/minio.deb" ] && rm -f /tmp/minio.deb

        # Download minio client
        mkdir -p $minioClientDir
        curl --progress-bar https://dl.min.io/client/mc/release/linux-amd64/mc -o $minioClientDir/mc >> $logFile
        if [ $? -ne 0 ]; then
            printErrorMessage "client download failure"
        else
            printSuccessMessage "client download"
        fi

        # Executable file
        chmod +x $minioClientDir/mc >> $logFile

        # Check minio alias
        $minioClientDir/mc alias list $minioAlias >> $logFile 2>&1
        if [ $? -ne 0 ]; then
            $minioClientDir/mc alias set $minioAlias http://$serverIp:$minioCliPort $minioUser $minioPassword >> $logFile
            if [ $? -ne 0 ]; then
                printErrorMessage "create an alias failure"
            else
                printSuccessMessage "create an alias"
            fi
        else
            printWarningMessage "this alias $minioAlias already exists, skip this step"
        fi

        # Check minio bucket
        $minioClientDir/mc ls $minioAlias/$minioBucket >> $logFile 2>&1
        if [ $? -ne 0 ]; then
            $minioClientDir/mc mb $minioAlias/$minioBucket >> $logFile
            if [ $? -ne 0 ]; then
                printErrorMessage "create a bucket failure"
            else
                printSuccessMessage "create a bucket"
            fi
            $minioClientDir/mc event add --event "put" $minioAlias/$minioBucket arn:minio:sqs::_:webhook >> $logFile
        else
            printWarningMessage "This bucket already exists: $minioAlias/$minioBucket, skip this step"
        fi

    else
        printWarningMessage "minio is already installed, skip this step"
    fi
}

# Docker
function dockerLogin {
    dockerRegistry=$1
    #echo $dockerGitlabPassword | docker login --username $dockerGitlabUser --password-stdin $dockerRegistry >> $logFile 2>&1
    echo "Connecting to $dockerRegistry"

    counter=1
    until docker login $dockerRegistry
    do
        sleep 1
        if [ $counter -eq $maxNumberAttempts ]; then
            printErrorMessage "$dockerRegistry login failure"
        else
            echo "Trying again. Try #$counter"
            ((counter++))
        fi
    done
    printSuccessMessage "$dockerRegistry login"
}

function dockerLogout {
    dockerRegistry=$1
    docker logout $dockerRegistry >> $logFile 2>&1
    if [ $? -ne 0 ]; then
        printErrorMessage "$dockerRegistry logout failure"
    else
        printSuccessMessage "$dockerRegistry logout"
    fi
}

function dockerDeploy {
    # Check if docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin are installed
    dpkg -s docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> $logFile 2>&1
    if [ $? -ne 0 ]; then
        if [ ! -d "/etc/apt/keyrings" ]; then
            mkdir -p /etc/apt/keyrings >> $logFile
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            printSuccessMessage "docker sources list added"
        fi
        
        aptUpdate

        apt-get -qq -o Dpkg::Progress-Fancy="1" install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        if [ $? -ne 0 ]; then
            printErrorMessage "service docker install failure"
        else
            printSuccessMessage "service docker install"
            systemctl enable docker
            systemctl start docker
        fi
    else
        printWarningMessage "docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin are already installed, skip this step"
    fi
}

# Treatment Planning System
function tpsDeploy {
    cd $tpsDir
    if [ ! -d "$tpsDir/.git" ]; then
        git init
        git config --global user.email "$tpsGitEmail"
        git config --global user.name "$tpsGitUserName"
        git remote add origin $tpsGitUrl
    else
        git add -A
        git commit -m "add new config files"
        git stash
    fi
    counter=1

    # If you need other then certain version on tpsLauncher use full SHA of commit (can be found in git)
    # e.g. until git pull ca07ce19ae9a6769779ffef270a15c6eba285ece master >> $logFile
    until git pull origin master >> $logFile
    do
        sleep 1
        if [ $counter -eq $maxNumberAttempts ]; then
            printErrorMessage "git login failure"
        else
            echo "Trying again. Try #$counter"
            ((counter++))
        fi
    done
    if [ ! -d "$tpsDir/.git" ]; then
        git stash pop
    fi
    printSuccessMessage "clone a repository"

    
    sed -i "s/{DB_IP_ADDRESS}/$serverIp/" $tpsBackendConfig
    sed -i "s/{DB_USER_PASSWORD}/$postgresNewPassword/" $tpsBackendConfig
    sed -i "s/{MINIO_IP_ADDRESS}/$minioIp/" $tpsBackendConfig
    sed -i "s/{MINIO_USER}/$minioPassword/" $tpsBackendConfig
    sed -i "s/{MINIO_PASSWORD}/$minioPassword/" $tpsBackendConfig

    sed -i "s/{minio_ip}/$minioIp/" $tpsMinioConfig

    sed -i "s/{BACKEND_IP_ADDRESS}/$serverIp/" $tpsComposeFile

    # Change db server and db password
    sed -i "s/{DB_IP_ADDRESS}/$serverIp/" $icdConfig
    sed -i "s/{DB_USER_PASSWORD}/$postgresNewPassword/" $icdConfig
    printSuccessMessage "prepare TPS config files"
}


# prepare ssl certificate
function sslDeploy {
    # Establish your private certificate authority (CA)
    openssl req -x509 -nodes          \
    -newkey RSA:2048                  \
    -keyout $tpsSslDir/root-ca.key    \
    -days $sslDays                    \
    -out $tpsSslDir/root-ca.crt       \
    -subj "/C=$sslC/ST=$sslST/L=$sslL/O=$sslO/CN=$sslO Root CA"
    
    # Create a private key and a certificate signing request (CSR) for your server
    openssl req -nodes            \
    -newkey rsa:2048              \
    -keyout $tpsSslDir/server.key \
    -out $tpsSslDir/server.csr    \
    -subj "/C=$sslC/ST=$sslST/L=$sslL/O=$sslO/CN=$sslCN"

    # Generate a certificate for your server
    openssl x509 -req              \
    -CA $tpsSslDir/root-ca.crt    \
    -CAkey $tpsSslDir/root-ca.key \
    -in $tpsSslDir/server.csr     \
    -out $tpsSslDir/server.crt    \
    -days $sslDays                \
    -CAcreateserial               \
    -extfile <(printf "subjectAltName = IP.1:$serverIp\nauthorityKeyIdentifier = keyid,issuer\nbasicConstraints = CA:FALSE\nkeyUsage = digitalSignature, keyEncipherment\nextendedKeyUsage=serverAuth")

    if [ $? -ne 0 ]; then
        printErrorMessage "create a certificate failure"
    else
        printSuccessMessage "create a certificate"
        cp $tpsSslDir/root-ca.crt $tpsDir/tps/ssl_instructions/root-ca.crt
    fi
}

# Start docker containers
function tpsStart {
    #echo $dockerGitlabPassword | docker login --username $dockerGitlabUser --password-stdin $dockerGitlabRegistry >> $logFile 2>&1
    echo "Connecting to $dockerGitlabRegistry"

    dockerLogin "$dockerGitlabRegistry"

    docker compose -f $tpsComposeFile up -d >> $logFile
    if [ $? -ne 0 ]; then
        printErrorMessage "run containers failure"
    else
        printSuccessMessage "run containers"
    fi

    dockerLogout "$dockerGitlabRegistry"
}

# Remove docker and docker-compose
function dockerRemove {
    # Check if ocker-ce docker-compose-plugin is installed
    dpkg -s docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> $logFile 2>&1
    if [ $? -eq 0 ]; then
        docker stop $(docker ps -a -q) >> $logFile 2>&1
        if [ $? -eq 0 ]; then
            printSuccessMessage "all docker containers stoped"
            
            docker rm $(docker ps -a -q)
            if [ $? -eq 0 ]; then
                printSuccessMessage "all docker containers removed"
            else
                printWarningMessage "not all docker containers were removed"
            fi
        else
            printWarningMessage "not all docker containers were stopped"
        fi

        docker system prune -af >> $logFile 2>&1
        if [ $? -eq 0 ]; then
            printSuccessMessage "docker has been successfully prune"
        else
            printWarningMessage "docker can't be prune"
        fi

        systemctl stop docker docker.socket >> $logFile 2>&1
        if [ $? -eq 0 ]; then
            printSuccessMessage "docker service has been successfully stopped"
        else
            printWarningMessage "docker service can't be stopped"
        fi

        apt-get -qqy -o Dpkg::Progress-Fancy="1" purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> $logFile 2>&1
        if [ $? -eq 0 ]; then
            printSuccessMessage "docker service has been successfully removed"
        else
            printWarningMessage "docker service can't be removed"
        fi
    else
        printWarningMessage "docker packeges not found, skip this step"
    fi
}

# Remove postgresql
function postgresqlRemove {
    # Check if postgresql is installed
    dpkg -s postgresql >> $logFile 2>&1
    if [ $? -eq 0 ]; then
        systemctl stop postgresql >> $logFile 2>&1
        if [ $? -eq 0 ]; then
            printSuccessMessage "Postgresql has been successfully stopped"
            apt-get -qqy -o Dpkg::Progress-Fancy="1" --purge remove postgresql postgresql-*
            if [ $? -eq 0 ]; then
                printSuccessMessage "Postgresql has been successfully removed"
                rm -rf {/var/{lib,log},etc}/postgresql/
                deluser postgres
            else
                printWarningMessage "Postgresql can't be removed"
                return 1
            fi
        else
            printWarningMessage "Postgresql can't be stopped"
            return 1
        fi
    else
        printWarningMessage "postgresql not found, skip this step"
        return 1
    fi
}

# Remove minio
function minioRemove {
    # Check minio alias
    if $minioClientDir/mc alias list $minioAlias >> $logFile 2>&1; then
        $minioClientDir/mc alias rm $minioAlias
        printSuccessMessage "removed minio alias $minioAlias"
    else
        printWarningMessage "alias $minioAlias not found, nothing to remove"
    fi
    [ -d "$minioClientDir" ] && rm -rf $minioClientDir

    # Check if minio is installedкнярщмкш
    dpkg -s minio >> $logFile 2>&1
    if [ $? -eq 0 ]; then
        systemctl disable minio >> $logFile 2>&1
        # Stop minio service
        systemctl stop minio >> $logFile 2>&1
        if [ $? -eq 0 ]; then
            printSuccessMessage "minio stopped successfully"

            apt-get -yqq -o Dpkg::Progress-Fancy="1" --purge remove minio
            if [ $? -eq 0 ]; then
                printSuccessMessage "Removed minio"
                if [ -d "$minioVolumes" ]; then
                    rm -rf $minioVolumes
                    printSuccessMessage "Removed minio data dir"
                else
                    printWarningMessage "minio data dir not found"
                fi

                if [ -f "/etc/default/minio" ]; then
                    rm -rf /etc/default/minio
                    printSuccessMessage "Removed minio config"
                else
                    printWarningMessage "minio config not found"
                fi
                deluser $minioSystemUser
            else
                printWarningMessage "minio can't be removed"
                return 1
            fi
        else
            printErrorMessage "minio stop failure"
            return 1
        fi
    else
        printWarningMessage "minio not found, skip this step"
        return 1
    fi
}
# Remove tps dir
function tpsRemove {
    printSuccess "Uninstalling tps project"
    if [ -d "$tpsDir" ]; then
        # Удаляем все файлы и папки, кроме лог-файла
        find "$tpsDir" -mindepth 1 ! -wholename "$logFile" -exec rm -rf {} +
        printSuccessMessage "Removed tps dir"
    else
        printWarningMessage "tps dir not found, skip this step"
        return 1
    fi
}

function tpsDirCheck {
    printSuccess "checking the TPS installation"
    if [ ! -d "$tpsDir/tps" ]; then
        printErrorMessage "TPS is not installed, please install TPS first"
    fi
}

# Treatment Planning System install
function tpsInstall {
    #Update repository, step 1
    printTaskMessage "Update repository"
    aptUpdate

    # Deploy SSH server, step 2
    printTaskMessage "Deploy SSH server"
    sshDeploy

    # Deploy curl, step 3
    printTaskMessage "Install curl"
    curlInstall

    # Deploy Postgresql, step 4
    printTaskMessage "Deploy Postgresql"
    postgresqlDeploy

    # Deploy Minio, step 5
    printTaskMessage "Deploy Minio"
    minioDeploy

    # Deploy Docker, step 6
    printTaskMessage "Deploy Docker"
    dockerDeploy

    # Deploy TPS, step 7
    printTaskMessage "Deploy TPS"
    tpsDeploy

    # Generation SSL crt. step 8
    printTaskMessage "Deploy ssl certificate"
    sslDeploy

    # Start docker containers. step 9
    printTaskMessage "Start docker containers"
    tpsStart

    echo -e
    echo -e
    echo -e
    printSuccess "###########################################################"
    printSuccess "#"
    printSuccess "# TPS successfully installed"
    printSuccess "# Use this address to connect: https://$serverIp/login"
    printSuccess "# View SSL instructions: http://$serverIp/cert/"
    printSuccess "#"
    printSuccess "###########################################################"
}

# Launch montecarlo docker service
function launchMontecarlo {
    tpsDirCheck
    dockerLogin "$dockerGitlabRegistry"
    docker compose -f $tpsComposeFile -f $montecarloComposeFile up -d >> $logFile
    if [ $? -ne 0 ]; then
        printErrorMessage "run container montecarlo failure"
    else
        printSuccessMessage "run container montecarlo"
    fi
    dockerLogout "$dockerGitlabRegistry"
}

# Launch pencilbeam docker service
function launchPencilbeam {
    tpsDirCheck
    dockerLogin "$dockerGitlabRegistry"
    docker compose -f $tpsComposeFile -f $pencilbeamComposeFile up -d >> $logFile
    if [ $? -ne 0 ]; then
        printErrorMessage "run container pencilbeam failure"
    else
        printSuccessMessage "run container pencilbeam"
    fi
    dockerLogout "$dockerGitlabRegistry"
}

# Launch orthanc docker service
function launchOrthanc {
    tpsDirCheck
    dockerLogin "$dockerGitlabRegistry"
    cd $tpsDir/PACS
    docker compose -f $orthancComposeFile up -d >> $logFile
    if [ $? -ne 0 ]; then
        printErrorMessage "run container orthanc failure"
    else
        printSuccessMessage "run container orthanc"
    fi
    dockerLogout "$dockerGitlabRegistry"
}

# Launch download depersonalized postgres dump
function launchDownloadDepersonalizedDump {
    # Название контейнера PostgreSQL
    tempDb="depersonalized_temp_db"
    BACKUP_DIR="./depersonalized_backup"

    setPostgresEnv

    echo "Creating a directory for backup"
    mkdir -p $BACKUP_DIR

    echo "Creating a backup"
    pg_dump -d $postgresTpsDb -F c -f $BACKUP_DIR/db_backup.dump

    # Checking the success of the backup creation
    if [ $? -eq 0 ]; then
        echo "Creating a temporary DB $tempDb"
        createdb $tempDb

        echo "Restoring a backup to a temporary database"
        pg_restore -d $tempDb $BACKUP_DIR/db_backup.dump

        echo "Using a depersonalizing script"
        psql -d $tempDb -f ./depersonalize.sql

        echo "Creating a depersonalized backup"
        pg_dump -d $tempDb -F c -f $BACKUP_DIR/db_depersonalized_backup.dump

        echo "Deleting a temporary DB $tempDb"
        dropdb $tempDb

        echo "Copy depersonalized backup to $(pwd)/db_depersonalized_backup.dump"
        cp $BACKUP_DIR/db_depersonalized_backup.dump ./db_depersonalized_backup.dump

        echo "Deleting a backup folder"
        rm -rf $BACKUP_DIR

        printSuccessMessage "Depersonalized backup has been created."
    else
        printErrorMessage "Error occurred while creating the backup."
    fi
}

# Treatment Planning System uninstall
function tpsUninstall {
    read -r -p "Are you sure? All data will be lost [y/N] " response
    response=${response,,}    # tolower
    if [[ "$response" =~ ^(yes|y)$ ]]; then
        dockerRemove
        dockerRemoveStatus=$?

        postgresqlRemove
        postgresqlRemoveStatus=$?

        minioRemove
        minioRemoveStatus=$?

        tpsRemove
        tpsRemoveStatus=$?

        if [ $dockerRemoveStatus -eq 0 ] && [ $postgresqlRemoveStatus -eq 0 ] && [ $minioRemoveStatus -eq 0 ] && [ $tpsRemoveStatus -eq 0 ]; then
            echo -e
            echo -e
            echo -e
            printSuccess "###########################################################"
            printSuccess "#"
            printSuccess "# TPS successfully uninstalled"
            printSuccess "#"
            printSuccess "###########################################################"
        fi
    fi
}


#------------------------------
# Start script
#------------------------------
# Check the script is being run by root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

# Create project dir
[ ! -d $tpsDir ] && mkdir $tpsDir 
# Create log file
[ ! -f "$logFile" ] && touch "$logFile"

PS3="Choose one of the items (press enter to see menu): "
options=("Install" "Launch montecarlo" "Launch pencilbeam" "Launch orthanc" "Download depersonalized dump" "Uninstall" "Quit")
select backup in "${options[@]}"
do
    case $backup in
        "Install")
            tpsInstall
            exit 0
            ;;
        "Launch montecarlo")
            launchMontecarlo
            exit 0
            ;;
        "Launch pencilbeam")
            launchPencilbeam
            exit 0
            ;;
        "Launch orthanc")
            launchOrthanc
            exit 0
            ;;
        "Download depersonalized dump")
            launchDownloadDepersonalizedDump
            exit 0
            ;;
        "Uninstall")
            tpsUninstall
            exit 0
            ;;
        "Quit") exit ;;
        *) echo "Invalid entry $REPLY" ;;
    esac
done