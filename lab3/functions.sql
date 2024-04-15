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
                IF have_different_structure(dev_table.TABLE_NAME, dev_schema_name, prod_schema_name) THEN
                    DBMS_OUTPUT.PUT_LINE(dev_table.table_name 
                        || ' IS DIFFERENT IN STRUCTURE');
                END IF;
                EXIT;
            END IF;
        END LOOP; 
        IF is_found = FALSE THEN          
            DBMS_OUTPUT.PUT_LINE(dev_table.table_name);
        END IF;
   END LOOP;
END;


CREATE OR REPLACE FUNCTION have_different_structure(table_name_to_check VARCHAR2, 
                                         dev_schema VARCHAR2, 
                                         prod_schema VARCHAR2)
RETURN BOOLEAN
AS
    TYPE columns_t IS TABLE OF VARCHAR2(100);
    dev_cols columns_t;
    prod_cols columns_t;
    diff_count NUMBER;
        
BEGIN
    SELECT COUNT(*) INTO diff_count FROM (
        (SELECT column_name FROM ALL_TAB_COLS
        WHERE table_name = table_name_to_check AND owner = dev_schema
        MINUS
        SELECT column_name FROM ALL_TAB_COLS
        WHERE table_name = table_name_to_check AND owner = prod_schema)
        UNION
        (SELECT column_name FROM ALL_TAB_COLS
        WHERE table_name = table_name_to_check AND owner = prod_schema
        MINUS
        SELECT column_name FROM ALL_TAB_COLS
        WHERE table_name = table_name_to_check AND owner = dev_schema));
    IF diff_count = 0 
    THEN
        RETURN FALSE;
    ELSE
        RETURN TRUE; 
    END IF;
END;



-- TEST--
SET SERVEROUTPUT ON;
EXEC GET_DIFFERENCES('DEV', 'PROD');
EXEC GET_DIFFERENCES('PROD', 'DEV');




