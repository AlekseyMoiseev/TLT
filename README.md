Ниже описана инструкция по развертыванию системы TPS на чистой машине под управлением Ubuntu Server. При написании инструкции использовалась система Ubuntu 20.0.4.

Здесь и далее {ip_адрес} это либо адрес сервера в локальной сети, либо внешний адрес (WAN) сети NAT, но тогда требуется редирект нужных портов.

При установке ОС обрати внимание:
а. на разметку диска (требуется увеличить раздел /, правки почти невозможны) и 
б. ip адрес (рекомендуется статика в момент установки, можно править через netplan).
в. установи галку openssh

0. Устанавливаем openssh (если это вдруг не сделано во время установки сервера):

sudo apt update
sudo apt install openssh-server
sudo ufw allow ssh

Проверяем:
sudo systemctl status ssh

Выход на q

Заходим или подключаемся к серверу (для Windows это Putty).

Копируем папку (tps) куда-нибудь на машину через WinSCP или иным методом. Переходим в папку. 

1. Установить postgresql

sudo apt-get update
sudo apt-get install postgresql

2. Подключиться
sudo -u postgres psql
 
3. Создать базу
create database treatmentplanningdb;

4. Поменять пароль для пользователя
ALTER USER postgres with encrypted password 'xxxxxxx';

где xxxxxxx - новый пароль
Выйти \q или Ctrl+D
 
5. Открываем базу для коннекта из докера (X.X - версия postgres):
sudo nano /etc/postgresql/X.X/main/postgresql.conf
и разкомментим строчку с listen_addresses и меняем на listen_addresses = '*'.
NOTE: Ниже описан порт, по которому нужно подключаться и его нужно будет указать в .env файле на шаге 15.
Сохраняем (Ctrl+X) и выходим.

6. Редактируем файл pg_hba.conf (X.X - версия postgres)
sudo nano /etc/postgresql/X.X/main/pg_hba.conf

поменять "peer" на "md5" на строке с пользователем postgres

Добавить строки в конец файла:

host    all             all              0.0.0.0/0                       md5
host    all             all              ::/0                            md5

Сохранить файл после этого (Ctrl+X).

7. Перезагрузить базу
sudo systemctl restart postgresql

8. Проверить, что пароль применился
psql -U postgres

9. Установить docker:

sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu `lsb_release -cs` test"
sudo apt update
sudo apt install docker-ce

Затем проверяем версию:
docker -v

9a. Выполняем:

sudo chmod 666 /var/run/docker.sock

9b. Выдаем sudo докеру. Выполняем:

sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

10. Установка https сертификатов.
a. Вставте свою ифнормацию в файл /tps/ssl/v3.ext и сохранить:

C = Двух символьный идентификатор страны (RU)
ST = Область
L = Город
O = Организация
OU = Подразделение
CN = Название сертификата
IP.1 = ip сервера (адрес по которому будем переходить).

b. В дериктории /tps/ssl/ выполнить:

openssl req -new -nodes -x509 -days 365 -keyout server.key -out server.crt -config ./v3.ext

c. Перекинуть server.crt на windows и применить его
-   Нажать "Установить сертификат", Далее
-   "Локальная машина", Далее
-   "Поместить сертификаты в выбранное место" и выбрать "Trusted Root Certificate Autorithies"
-   Далее и закончить.

11. Выполняем настройку и запуск Minio

11a.  Установка
wget https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20221212192727.0.0_amd64.deb -O minio.deb
sudo dpkg -i minio.deb

11b. Создаем группу для minio
sudo groupadd -r minio-user

11c. Создаем пользователя и добавляем в группу:
sudo useradd -M -r -g minio-user minio-user

11d. Создаем папку, где minio будет хранить файлы
sudo mkdir /mnt/data

11e. Выдаем доступ группе и пользователю к новой папке:
sudo chown minio-user:minio-user /mnt/data

11f. Создаем файл конфигурации и заполняем
sudo nano /etc/default/minio

-   Вставить

MINIO_VOLUMES="/mnt/data"

MINIO_OPTS="--console-address :9001"

MINIO_ROOT_USER=minioadmin

MINIO_ROOT_PASSWORD=minioadmin

MINIO_NOTIFY_WEBHOOK_ENABLE=on

MINIO_NOTIFY_WEBHOOK_ENDPOINT=http://localhost:5180/BucketNotifications

-   Сохранить



11g. Перезапускаем все сервисы

sudo systemctl daemon-reload

11h. Активировать сервис
sudo systemctl enable minio

11i. Проверяем статус сервиса:
sudo systemctl status minio

Должно появиться что-то такое:
minio.service - MinIO
     Loaded: loaded (/etc/systemd/system/minio.service; disabled; vendor preset: enabled)
     Active: **active** (running) since Mon 2022-05-23 02:55:03 UTC; 2s ago

11j. 5.В браузере открываем страницу http://{ip_адрес_сервера}:9001 и авторизуемся
Нажать кнопку “Create bucket”
Указываем имя “appointment” и нажимаем кнопку “Create bucket”
Переходим в настройки бакета
Переходим в раздел “Events” и нажимаем “Subscribe to Event”
Выбираем в поле webhook единственное значение, выбирает put в методе и сохраняем.

12. Редактируем файл tps/backend/.env
 меняем TreatmentPlanningDb=Server={192.168.47.128} на текущий ip машины
 (меняем) Password и Database берем из Шагов 4 и 3.
 (меняем) Port на значение из Шага 6.
 меняем CommonSettings__MinioSettings__Host на текущий ip машины, где установлен Minio
 меняем CommonSettings__MinioSettings__UserName на логин для подключения к Minio
 меняем CommonSettings__MinioSettings__Password на пароль для подключения к Minio

13. В tps/cors/minio.conf меняем {minio_ip_address} на ip адрес машины, где установлен Minio

14. Редактируем файл tps/docker-compose.yml
 меняем в строчке 29 API_BASE_URL слово localhost на текущий ip машины.

15. Не забыть вставить ключ USB.

16. Логинимся в gitlab registry, чтобы скачать образы
docker login registry.gitlab.com
Используем username и deploy token из gitlab
alexei.moiseev
пароль deploy token от gitlab

17. Переходим в корень tps и запускаем:
docker compose up

18. Если все ок, то переходим на http://(текущий ip машины)/.

19. Выходим из gitlab (обязательная чистка кредов, чтобы после этого нельзя было скачать docker образы)
docker logout registry.gitlab.com

## Установка PACS
1. Переходим в директорию:
cd ./PACS

2. Проверяем настройки в файлах docker-compose.yml и orthanc.json, где
 "MaximumStorageSize" : 10000, // Максимальный размер хранилища в МБ, значение "0" означает, что нет ограничений

3. Создаем папку:
mkdir orthanc_data

4. Выполняем команду:
docker compose up -d

## Применить сертификаты для браузеров Ubuntu
0. Остановить docker compose down из папки tps (/opt/tps/tps). Перейти в ssl, там все удалить кроме v3.ext
1. openssl genrsa -des3 -out rootCA.key 2048
Вводим любые данные. Пароль везде указываем 123456789
2. openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1825 -out rootCA.pem
3. openssl genrsa -out server.key 2048
4. openssl req -new -key server.key -out server.csr
5. NANO openssl.cnf
Вставляем:
# Extensions to add to a certificate request
basicConstraints       = CA:FALSE
authorityKeyIdentifier = keyid:always, issuer:always
keyUsage               = nonRepudiation, digitalSignature, keyEncipherment, dataEncipherment
subjectAltName         = @alt_names
[ alt_names ]
IP.1 = {ТУТ IP ВАШЕГО СЕРВАКА, можно взять эту строчку из v3.ext}

6. Сохраняем
7. openssl x509 -req \
    -in server.csr \
    -CA rootCA.pem \
    -CAkey rootCA.key \
    -CAcreateserial \
    -out server.crt \
    -days 1825 \
    -sha256 \
    -extfile openssl.cnf
8. Запускает docker compose up
9. Устанавливаем сертификат в Chrome ubuntu:

Chrome -> Settings -> Privacy and security -> Security -> Manage Certificates -> Authorities -> Import (Импортируем из папки ssl rootCA.pem)
10. Перезапускаем Chrome и переходим по IP
11. ОПЦИОНАЛЬНоО. Для windows Chrome из папки ssl выполняем:
openssl x509 -outform der -in rootCA.pem -out rootCA.crt
Переносим rootCA.crt на windwos и устанавливаем.

12. Добавляем cert в Firefox, Ubuntu (источник: https://dev.to/lmillucci/firefox-installing-self-signed-certificate-on-ubuntu-4f11):
a. Переходим в браузере:
about:profiles
b. Копируем первый root directory
c. Устанавливаем утилиту:
sudo apt install libnss3-tools
d. Добавляем cert:
certutil -A -n "<CERT_NICKNAME>" -t "TC,," -i <PATH_FILE_CRT> -d sql:<FIREFOX_PROFILE_PATH>
где 
CERT_NICKNAME: название cert
PATH_FILE_CRT: путь до файла серт
FIREFOX_PROFILE_PATH: путь до базы браузера (п.2)

Пример:
certutil -A -n "RT7" -t "TC,," -i /opt/tps/tps/ssl/server.crt -d sql:/home/ubuntu/.mozilla/firefox/r17y2icz.default-release

e. Перезапускаем браузер.

NOTE: Возможно понадобится sudo для операций с 1-7



### Деперсонализация бэкапа БД
1. В TPSLauncher запустить пункт "Download depersonalized dump". На выходе получаем бэкап БД с деперсонализированными данными пациентов.
2. Получившийся dump файл db_depersonalized_backup.dump с деперсонализированными данными пациентов скопировать на компьютер где будет разворачиваться БД или в докер контейнер с Postgres.
3. Экспортировать postgres переменные окружения в окружение linux:
    export PGHOST=serverIp
    export PGPORT=postgresPort
    export PGUSER=postgresUser
    export PGPASSWORD=postgresPassword
4. Создать БД если нужно:
createdb restoreDB
5. ​Запустить утилиту по восстановлению дампа в БД restoreDB:
pg_restore -d restoreDB BACKUP_DIR/db_depersonalized_backup.dump