#!/bin/bash

# Settings
now=$(date +"%Y-%m-%dT%H%M")
dir=$(pwd)
serverIp=$(hostname -I | cut -d' ' -f1)
tpsCollectorLog="$dir/tps-collector.log"
tpsBackupDir="$dir/backup"

postgresqlUser="postgres"
postgresqlDb="treatmentplanningdb"

# Project dir
tpsDir="/opt/tps/tps/"
# Storage path
storageDir="tps_data/storage"
# Minio path
minioDir="minio"

backendContainerName="backend"
frontendContainerName="frontend"



# Print task message to console
function printTaskMessage {
    # Number of steps
    if [ -z $STEPS ]; then
        STEPS=1
    fi
    i=$((i+1))
    echo -e "[ $i/$STEPS ] $1 ******************************************************************"
}

function unsetTaskMessage {
    unset i
    unset STEPS
}

function printSuccessMessage {
    echo -e "\033[32mok: $1\033[0m"
}

function printWarningMessage {
    echo -e "\033[33mwarn: $1\033[0m"
}

function printErrorMessage {
    echo -e "\033[31merror: $1\033[0m"
    #exit
}

function installTools {
    dpkg -s pv >> $tpsCollectorLog 2>&1
    if [ $? -ne 0 ]; then
        apt-get -qq -o Dpkg::Progress-Fancy="1" install pv
        if [ $? -ne 0 ]; then
                printErrorMessage "tools installation failure"
        else
                printSuccessMessage "tools install"
        fi
    fi
}

# Creating a backup based on the current state of postgresql
function postgresqlBackup {
    printTaskMessage "Backup PostgreSQL"
    postgresqlDumpFile="$tpsBackupDir/$now.postgresql.dump"
    pg_dump -Fc -h $serverIp -U $postgresqlUser $postgresqlDb > $postgresqlDumpFile
    if [ $? -ne 0 ]; then
        printErrorMessage "Can't dump database: $postgresqlDb"
    else
        printSuccessMessage "The dump file was created successfully: $postgresqlDumpFile"
    fi
}

# Creating a backup based on the current state of minio
function minioBackup {
    printTaskMessage "Backup MinIO"
    installTools
    if [ -d "$tpsDir$minioDir" ]; then
        minioBackupFile="$tpsBackupDir/$now.minio.tar.gz"
        tar -C $tpsDir -czf - $minioDir | (pv -p --timer --rate --bytes > $minioBackupFile)
        if [ $? -ne 0 ]; then
            printErrorMessage "Can't backup minio: $tpsDir$minioDir"
        else
            printSuccessMessage "Minio backup was created successfully: $minioBackupFile"
        fi
    else
        printErrorMessage "Can't find path: $tpsDir$minioDir"
    fi
}

# Creating a backup based on the current state of storage
function storageBackup {
    printTaskMessage "Backup Storage"
    installTools
    if [ -d "$tpsDir$storageDir" ]; then
        storageBackupFile="$tpsBackupDir/$now.storage.tar.gz"
        tar -C $tpsDir -czf - $storageDir | (pv -p --timer --rate --bytes > $storageBackupFile)
        if [ $? -ne 0 ]; then
            printErrorMessage "Can't backup storage: $tpsDir$storageDir"
        else
            printSuccessMessage "Storage backup was created successfully: $storageBackupFile"
        fi
    else
        printErrorMessage "Can't find path: $tpsDir$storageDir"
    fi
}

# Creating a backup based on the current state of backend
function backendBackup {
    printTaskMessage "Get backend log"
    backendDockerName=$(docker ps --format '{{.Names}}' | grep -i $backendContainerName)
    if [ -z $backendDockerName ]; then
        printErrorMessage "can't find container: $backendContainerName"
    else
        # get image name and version
        imageName=$(docker inspect --format '{{ .Config.Image }}' $backendDockerName)
        IFS='/' read -ra my_array <<< "$imageName"
        imageVersion=${my_array[4]}

        backendLogFile="$tpsBackupDir/$now.$backendDockerName.$imageVersion.log"
        docker logs $backendDockerName > $backendLogFile 2>&1
        printSuccessMessage "Batch-retrieves log was successful: $backendLogFile"
    fi
}

# Creating a backup based on the current state of frontend
function frontendBackup {
    printTaskMessage "Get frontend log"
    frontendDockerName=$(docker ps --format '{{.Names}}' | grep -i $frontendContainerName)
    if [ -z $frontendDockerName ]; then
        printErrorMessage "Can't find container: $frontendContainerName"
    else
        # get image name and version
        imageName=$(docker inspect --format '{{ .Config.Image }}' $frontendDockerName)
        IFS='/' read -ra my_array <<< "$imageName"
        imageVersion=${my_array[4]}

        frontendLogFile="$tpsBackupDir/$now.$frontendDockerName.$imageVersion.log"
        docker logs $frontendDockerName > $frontendLogFile 2>&1
        printSuccessMessage "Batch-retrieves log was successful: $frontendLogFile"
    fi
}

# Creating an archive of all files
function createArchive {
    printTaskMessage "Collect all files"
    ls -l $tpsBackupDir/ | grep $now > /dev/null
    if [ $? -ne 0 ]; then
        printErrorMessage "No files found for archiving "
    else
        allFiles="$dir/$now.all.tar.gz"
        cd $tpsBackupDir
        tar -czf - . | (pv -p --timer --rate --bytes > $allFiles)
        if [ $? -ne 0 ]; then
            printErrorMessage "Can't create archive"
        else
            printSuccessMessage "Archive was created successfully: $allFiles"
        fi
    fi

}

# Creating all backup based on the current state
function allBackup {
    # Number of steps
    STEPS=6
    postgresqlBackup
    minioBackup
    storageBackup
    backendBackup
    frontendBackup
    createArchive
}


#--------------------------
# Start backup script
#--------------------------

# Create a backup directory
if [ ! -d "$dir/backup/" ]; then
    mkdir $dir/backup/ >> $tpsCollectorLog
    if [ $? -ne 0 ]; then
        printErrorMessage "create backup dir failure: $dir/backup/"
    else
        printSuccessMessage "create backup dir: $dir/backup/"
    fi
else
    rm -rf $dir/backup/*
fi

# Check the script is being run by root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root"
   exit 1
fi

PS3="What type of backup do you want to make (press enter to see menu): "
options=("Postgresql" "Minio" "Storage" "Backend" "Frontend" "All" "Quit")
select backup in "${options[@]}"
do
    unsetTaskMessage
    case $backup in
        "Postgresql")
            postgresqlBackup
            ;;
        "Minio")
            minioBackup
            ;;
        "Storage")
            storageBackup
            ;;
        "Backend")
            backendBackup
            ;;
        "Frontend")
            frontendBackup
            ;;
        "All")
            allBackup
            ;;
        "Quit") exit ;;
        *) echo "Invalid entry $REPLY" ;;
    esac
done