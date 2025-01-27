-- Создаем временную таблицу с порядковым номером
WITH NumberedPatients AS (
    SELECT 
        "Id",
        ROW_NUMBER() OVER (ORDER BY "Id") AS "Number",
		'2000-01-01'::DATE - INTERVAL '1 day' * FLOOR(RANDOM() * (365 * 80)) AS "Birthdate"
    FROM 
        public."Patient"
)
-- Обновляем таблицу Patient
UPDATE public."Patient"
SET
    "FirstName" = 'Имя {' || np."Number" || '}',
    "MiddleName" = 'Отчество {' || np."Number" || '}',
    "LastName" = 'Фамилия {' || np."Number" || '}',
    "BirthDate" = np."Birthdate",
    "Note" = 'Заметки',
    "Ssn" = 'СНИЛС {' || np."Number" || '}',
    "Region" = 'Регион',
    "City" = 'Город',
    "Address" = 'Адрес',
    "Phone" = '+79999999999',
    "Email" = 'test@test.com'
FROM 
    NumberedPatients np
WHERE 
    public."Patient"."Id" = np."Id";
-- Обновляем таблицу PatientLog
UPDATE public."PatientLog"
SET
    "DataOld" = '',
    "DataNew" = ''
WHERE
    "Title" IN ('Создание карточки пациента', 'Обновление карточки пациента');