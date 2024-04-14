CREATE OR REPLACE PROCEDURE get_differences(dev_schema_name VARCHAR2, 
                                            prod_schema_name VARCHAR2) 
AS
BEGIN
    DBMS_OUTPUT.PUT_LINE("hello");
END;


DECLARE
    dev_tables ALL_TABLES%ROWTYPE;
BEGIN
    SELECT * BULK COLLECT INTO dev_tables FROM ALL_TABLES WHERE OWNER = 'DEV';
END;

SELECT TABLE_NAME BULK COLLECT INTO prod_tables FROM ALL_TABLES WHERE OWNER = 'PROD';



CREATE OR REPLACE PROCEDURE get_differences(dev_schema_name VARCHAR2, 
                                            prod_schema_name VARCHAR2)
AS
    CURSOR dev_tables IS SELECT * FROM ALL_TABLES WHERE OWNER = dev_schema_name;
    CURSOR prod_tables IS SELECT * FROM ALL_TABLES WHERE OWNER = prod_schema_name;
    is_found BOOLEAN := FALSE;
BEGIN
    FOR dev_table IN dev_tables LOOP
        is_found := FALSE;
        FOR prod_table IN prod_tables LOOP
            IF prod_table.TABLE_NAME = dev_table.TABLE_NAME THEN
                is_found := TRUE;
                EXIT;
            END IF;
        END LOOP; 
        IF is_found = FALSE THEN          
            DBMS_OUTPUT.PUT_LINE(dev_table.table_name);
        END IF;
   END LOOP;
END;

SET SERVEROUTPUT ON;
EXEC GET_DIFFERENCES('DEV', 'PROD');
EXEC GET_DIFFERENCES('PROD', 'DEV');


