CREATE OR REPLACE PROCEDURE get_differences(dev_schema_name VARCHAR2, 
                                            prod_schema_name VARCHAR2)
AS
    CURSOR dev_tables IS SELECT TABLE_NAME FROM ALL_TABLES 
        WHERE OWNER = dev_schema_name;
    CURSOR prod_tables IS SELECT OBJECT_NAME AS TABLE_NAME 
        FROM ALL_OBJECTS WHERE OBJECT_TYPE = 'TABLE' 
        AND OWNER = prod_schema_name ORDER BY CREATED ASC;
    is_found BOOLEAN := FALSE;
BEGIN
    FOR prod_table IN prod_tables LOOP
        is_found := FALSE;
        FOR dev_table IN dev_tables LOOP
            IF prod_table.TABLE_NAME = dev_table.TABLE_NAME THEN
                is_found := TRUE;
                IF have_different_structure(dev_table.TABLE_NAME, dev_schema_name, prod_schema_name) THEN
                    DBMS_OUTPUT.PUT_LINE('Table ' || dev_table.table_name 
                        || ' has different structure.');
                ELSIF have_different_constraints(dev_table.TABLE_NAME, dev_schema_name, prod_schema_name) THEN
                    DBMS_OUTPUT.PUT_LINE('Table ' || dev_table.table_name 
                        || ' has different constraints.');
                END IF;
                EXIT;
            END IF;
        END LOOP; 
        IF is_found = FALSE THEN          
            DBMS_OUTPUT.PUT_LINE(prod_table.table_name);
        END IF;
    END LOOP;
   
    FOR dev_table IN dev_tables LOOP
        search_for_cyclic_references(dev_table.table_name, dev_schema_name);
    END LOOP;
    FOR prod_table IN prod_tables LOOP
        search_for_cyclic_references(prod_table.table_name, prod_schema_name);
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


CREATE OR REPLACE FUNCTION have_different_constraints(table_name_to_check VARCHAR2, 
                                                      dev_schema VARCHAR2, 
                                                      prod_schema VARCHAR2)
RETURN BOOLEAN
AS
    diff_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO diff_count FROM (
        (SELECT CONSTRAINT_NAME FROM ALL_CONSTRAINTS
        WHERE owner = dev_schema AND table_name = table_name_to_check 
        AND constraint_name NOT LIKE 'SYS%' 
        MINUS 
        SELECT CONSTRAINT_NAME FROM ALL_CONSTRAINTS
        WHERE owner = prod_schema AND table_name = table_name_to_check
        AND constraint_name NOT LIKE 'SYS%') 
        UNION
        (SELECT CONSTRAINT_NAME FROM ALL_CONSTRAINTS
        WHERE owner = prod_schema AND table_name = table_name_to_check
        AND constraint_name NOT LIKE 'SYS%' 
        MINUS 
        SELECT CONSTRAINT_NAME FROM ALL_CONSTRAINTS
        WHERE owner = dev_schema AND table_name = table_name_to_check
        AND constraint_name NOT LIKE 'SYS%'));
    IF diff_count = 0 THEN
        RETURN FALSE;
    ELSE 
        RETURN TRUE;  
    END IF;
END;


CREATE OR REPLACE PROCEDURE search_for_cyclic_references(
    table_name_to_check VARCHAR2, 
    schema_name VARCHAR2
)
AS
BEGIN
    FOR cycle_row IN 
    (
        SELECT references_path FROM
        (WITH r_constraints_table (constraint_name, referencer_table, referenced_table) 
        AS (
            SELECT r_constraints.constraint_name, 
                   r_constraints.table_name referencer_table, 
                   p_constraints.table_name referenced_table
            FROM ALL_CONSTRAINTS r_constraints JOIN ALL_CONSTRAINTS p_constraints 
            ON r_constraints.r_constraint_name = p_constraints.constraint_name 
            WHERE r_constraints.constraint_type = 'R' 
            AND r_constraints.owner = schema_name
        ), 
        recursive_table (
            referenced_table, 
            referencer_table, 
            steps_count, 
            references_path
        ) AS ( 
            SELECT referenced_table, referencer_table, 1, referencer_table
            FROM r_constraints_table
            WHERE referencer_table = table_name_to_check
            UNION ALL
            SELECT r_constraints_table.referenced_table, 
                   r_constraints_table.referencer_table, 
                   steps_count + 1, 
                   recursive_table.references_path || ' -> ' || r_constraints_table.referencer_table
            FROM r_constraints_table
            JOIN recursive_table 
            ON r_constraints_table.referencer_table = recursive_table.referenced_table
        ) CYCLE referenced_table SET is_cycle TO '1' DEFAULT '0'
        SELECT referenced_table, referencer_table, is_cycle, steps_count, references_path
        FROM recursive_table WHERE is_cycle = 1)
    )
    LOOP
        IF REGEXP_LIKE(cycle_row.references_path, 
            REGEXP_SUBSTR(cycle_row.references_path, '[^ ]+', 1, 1) || '$') = true
        THEN
            DBMS_OUTPUT.PUT_LINE('Detected cycle: ' || cycle_row.references_path 
                || ' (schema: ''' || schema_name || ''').');
        END IF;
    END LOOP;
END;




-- TEST--
SET SERVEROUTPUT ON;
EXEC GET_DIFFERENCES('DEV', 'PROD');
EXEC GET_DIFFERENCES('PROD', 'DEV');


     
     