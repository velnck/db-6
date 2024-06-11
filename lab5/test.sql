-- TESTS
DELETE FROM
    organization;

DELETE FROM
    departments;

DELETE FROM
    employees;

DELETE FROM
    organization_logs;

DELETE FROM
    departments_logs;

DELETE FROM
    employees_logs;

DELETE from
    reports_logs;

INSERT INTO
    organization (organization_name, creation_date)
VALUES
(
        'o1',
        TO_TIMESTAMP('01-MAY-24 06.41.25.789000000 AM', 'DD-MON-RR HH.MI.SS.FF9 PM')   
    );

INSERT INTO
    organization (organization_name, creation_date)
VALUES
(
        'o2',
        TO_TIMESTAMP('01-MAY-24 06.41.24.789000000 AM', 'DD-MON-RR HH.MI.SS.FF9 PM')   
    );

INSERT INTO
    organization (organization_name, creation_date)
VALUES
(
        'o3',
        TO_TIMESTAMP('02-MAY-24 08.45.45.789000000 AM', 'DD-MON-RR HH.MI.SS.FF9 PM')   
    );

UPDATE
    organization
SET
    creation_date = systimestamp
WHERE
    organization_name = 'o1';

DELETE FROM
    organization
WHERE
    organization_name = 'o3';

SELECT
    *
FROM
    organization_logs
ORDER BY
    change_date;

SELECT
    *
FROM
    organization
ORDER BY
    organization_id;

CALL func_package.roll_back(30000);
CALL func_package.report();

CALL func_package.roll_back(to_timestamp('03-MAY-24 08.12.46.960000000 PM', 'DD-MON-RR HH.MI.SS.FF9 PM'));

--CALL func_package.roll_back(1200000);

CALL func_package.report();

CALL func_package.report(to_timestamp('01-MAY-24 09.07.46.926000000 PM', 'DD-MON-RR HH.MI.SS.FF9 PM'));


SELECT
    *
FROM
    organization_logs
ORDER BY
    change_date;

SELECT
    *
FROM
    organization
ORDER BY
    organization_id;