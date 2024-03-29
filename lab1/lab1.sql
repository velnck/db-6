--------------------------------------------
-- 1
--------------------------------------------

CREATE TABLE MyTable (
    id      NUMBER        GENERATED BY DEFAULT ON NULL AS IDENTITY PRIMARY KEY,
    val     NUMBER
);



--------------------------------------------
-- 2
--------------------------------------------

DECLARE
    v_count NUMBER;
BEGIN
    FOR v_count IN 1..10000
    LOOP
        INSERT INTO MyTable (id, val) 
        VALUES (v_count, ROUND(DBMS_RANDOM.VALUE(1, 10000), 0));
    END LOOP;
END;



--------------------------------------------
-- 3
--------------------------------------------

CREATE OR REPLACE FUNCTION even_values_more_than_odd RETURN VARCHAR2
IS
    result_count NUMBER(6, 0) := 0;
    result_message VARCHAR2(6);
BEGIN
    SELECT SUM(DECODE(
        REMAINDER(val, 2), 
        0, 1, 
        1, -1,
        -1, -1)
    ) INTO result_count
    FROM MyTable;
    SELECT 
        CASE  
        WHEN result_count < 0 THEN 'FALSE'
        WHEN result_count = 0 THEN 'EQUAL'
        ELSE 'TRUE'
        END
    INTO result_message FROM DUAL;
    DBMS_OUTPUT.PUT_LINE(UTL_LMS.FORMAT_MESSAGE('%s', result_message));
    RETURN result_message;
END;


set serveroutput on
DECLARE 
    result_message VARCHAR2(6);
BEGIN
    result_message := even_values_more_than_odd();
END;



--------------------------------------------
-- 4
--------------------------------------------

CREATE OR REPLACE FUNCTION get_insert_query(id NUMBER, val NUMBER) 
RETURN VARCHAR2
IS
    result_message VARCHAR2(100);
BEGIN
    result_message := UTL_LMS.FORMAT_MESSAGE(
        'INSERT INTO MyTable (id, val) VALUES (%d, %d);', 
        TO_CHAR(id), TO_CHAR(val)
    );
    DBMS_OUTPUT.PUT_LINE(result_message);
    RETURN result_message;
END;


set serveroutput on
DECLARE 
    result_message VARCHAR2(100);
BEGIN
    result_message := get_insert_query(10001, 12);
END;



--------------------------------------------
-- 5
--------------------------------------------

CREATE OR REPLACE PROCEDURE insert_operation(table_name VARCHAR2, val NUMBER, new_id OUT NUMBER) 
IS
BEGIN
	EXECUTE IMMEDIATE utl_lms.format_message(
        'INSERT INTO %s(val) VALUES (%d) RETURNING id INTO :1', 
        table_name, TO_CHAR(val)
    ) RETURNING INTO new_id;
END;

CREATE OR REPLACE PROCEDURE update_operation(table_name VARCHAR2, id NUMBER, val NUMBER) 
IS
BEGIN
	EXECUTE IMMEDIATE utl_lms.format_message(
        'UPDATE %s SET val=%d WHERE id=%d;', 
        table_name, TO_CHAR(val), TO_CHAR(id)
    );
END;	

CREATE OR REPLACE PROCEDURE delete_operation(table_name VARCHAR2, id NUMBER) 
IS
BEGIN
	EXECUTE IMMEDIATE utl_lms.format_message(
        'DELETE FROM %s WHERE id=%d;', 
        table_name, TO_CHAR(id)
    );
END;



set serveroutput on
DECLARE
    new_id NUMBER;
BEGIN
    insert_operation('MyTable', 14, new_id);
    DBMS_OUTPUT.PUT_LINE(UTL_LMS.FORMAT_MESSAGE('new id is %d', TO_CHAR(new_id)));
end;

EXEC update_operation('MyTable', 10001, 201);
SELECT * FROM mytable WHERE id = 10001;

EXEC delete_operation('MyTable', 10001);
SELECT * FROM mytable WHERE id = 10001;



--------------------------------------------
-- 6
--------------------------------------------

CREATE OR REPLACE FUNCTION get_annual_salary(
    monthly_wage NUMBER, 
    bonus_percent PLS_INTEGER
) RETURN NUMBER
IS
    result_value NUMBER;
    negative_percent EXCEPTION;
    wage_not_positive EXCEPTION;
BEGIN   
    IF bonus_percent < 0 THEN
        RAISE negative_percent;        
    END IF;
    IF monthly_wage <= 0 THEN
        RAISE wage_not_positive;        
    END IF;
    result_value := (1 + 0.01 * bonus_percent) * 12 * monthly_wage;
    RETURN  result_value;
EXCEPTION
    WHEN negative_percent THEN
        DBMS_OUTPUT.PUT_LINE('Negative bonus percent!');
        RETURN -1;
    WHEN wage_not_positive THEN 
        DBMS_OUTPUT.PUT_LINE('Monthly wage is not positive!');
        RETURN -1;
    WHEN OTHERS THEN 
        DBMS_OUTPUT.PUT_LINE('Some exception occurred!');
        RETURN -1;
END;


SET SERVEROUTPUT ON
DECLARE
    res NUMBER;
BEGIN
    res := get_annual_salary(141, 10);    
    DBMS_OUTPUT.PUT_LINE(UTL_LMS.FORMAT_MESSAGE('%d', TO_CHAR(res)));
END;



