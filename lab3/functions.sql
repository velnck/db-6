CREATE OR REPLACE PROCEDURE get_differences(dev_schema_name VARCHAR2, 
                                            prod_schema_name VARCHAR2)
AS
BEGIN
    compare_tables(dev_schema_name, prod_schema_name);
    compare_functions(dev_schema_name, prod_schema_name);
    compare_indexes(dev_schema_name, prod_schema_name);
    compare_packages(dev_schema_name, prod_schema_name);
END;


CREATE OR REPLACE PROCEDURE compare_tables(dev_schema_name VARCHAR2, 
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


CREATE OR REPLACE PROCEDURE compare_functions(dev_schema_name VARCHAR2, 
                                              prod_schema_name VARCHAR2)
AS
    CURSOR dev_functions IS SELECT OBJECT_NAME, OBJECT_TYPE
        FROM ALL_OBJECTS WHERE OBJECT_TYPE IN ('PROCEDURE', 'FUNCTION')
        AND OWNER = dev_schema_name;
    CURSOR prod_functions IS SELECT OBJECT_NAME, OBJECT_TYPE 
        FROM ALL_OBJECTS WHERE OBJECT_TYPE IN ('PROCEDURE', 'FUNCTION') 
        AND OWNER = prod_schema_name ORDER BY CREATED ASC;
    is_found BOOLEAN := FALSE;
BEGIN
    FOR prod_function IN prod_functions LOOP
        is_found := FALSE;
        FOR dev_function IN dev_functions LOOP
            IF prod_function.OBJECT_NAME = dev_function.OBJECT_NAME THEN
                is_found := TRUE;
                IF have_different_arguments(dev_function.OBJECT_NAME, dev_schema_name, prod_schema_name, NULL) THEN
                    DBMS_OUTPUT.PUT_LINE('Function ' || dev_function.OBJECT_NAME 
                        || ' has different arguments.');
                ELSIF have_different_text(dev_function.OBJECT_NAME, dev_schema_name, prod_schema_name, dev_function.object_type) THEN
                    DBMS_OUTPUT.PUT_LINE('Function ' || dev_function.OBJECT_NAME 
                        || ' has different text.');
                END IF;
                EXIT;
            END IF;
        END LOOP; 
        IF is_found = FALSE THEN          
            DBMS_OUTPUT.PUT_LINE('Funciton ' || prod_function.object_name);
        END IF;
    END LOOP;
END;


CREATE OR REPLACE FUNCTION have_different_arguments(function_name VARCHAR2, 
                                                    dev_schema_name VARCHAR2, 
                                                    prod_schema_name VARCHAR2,
                                                    package_name_arg VARCHAR2)
RETURN BOOLEAN
AS
    TYPE argument_record_t IS RECORD 
    (
        argument_name ALL_ARGUMENTS.argument_name%TYPE,
        position ALL_ARGUMENTS.position%TYPE, 
        data_type ALL_ARGUMENTS.data_type%TYPE, 
        in_out ALL_ARGUMENTS.in_out%TYPE
    );
    TYPE arguments_table_t IS TABLE OF argument_record_t;
    dev_arguments arguments_table_t;
    prod_arguments arguments_table_t;
BEGIN
    IF package_name_arg IS NULL THEN
        SELECT argument_name, position, data_type, in_out 
            BULK COLLECT INTO dev_arguments FROM ALL_ARGUMENTS 
            WHERE OWNER = dev_schema_name AND OBJECT_NAME = function_name
            AND package_name IS NULL
            ORDER BY position;
        SELECT argument_name, position, data_type, in_out 
            BULK COLLECT INTO prod_arguments FROM ALL_ARGUMENTS 
            WHERE OWNER = prod_schema_name AND OBJECT_NAME = function_name
            AND package_name IS NULL
            ORDER BY position;
    ELSE
         SELECT argument_name, position, data_type, in_out 
            BULK COLLECT INTO dev_arguments FROM ALL_ARGUMENTS 
            WHERE OWNER = dev_schema_name AND OBJECT_NAME = function_name
            AND package_name = package_name_arg
            ORDER BY position;
        SELECT argument_name, position, data_type, in_out 
            BULK COLLECT INTO prod_arguments FROM ALL_ARGUMENTS 
            WHERE OWNER = prod_schema_name AND OBJECT_NAME = function_name
            AND package_name = package_name_arg
            ORDER BY position;
    END IF;
    IF dev_arguments.COUNT != prod_arguments.COUNT THEN
        RETURN TRUE;
    END IF;
    FOR i IN 1..dev_arguments.COUNT LOOP
        IF dev_arguments(i).argument_name != prod_arguments(i).argument_name 
            OR dev_arguments(i).position != prod_arguments(i).position
            OR dev_arguments(i).data_type != prod_arguments(i).data_type
            OR dev_arguments(i).in_out != prod_arguments(i).in_out 
        THEN
            RETURN TRUE;
        END IF;
    END LOOP;
    RETURN FALSE;
END;


CREATE OR REPLACE PROCEDURE compare_indexes(dev_schema_name VARCHAR2, 
                                            prod_schema_name VARCHAR2)
AS
    CURSOR dev_indexes IS SELECT index_name FROM ALL_INDEXES 
        WHERE OWNER = dev_schema_name AND index_name NOT LIKE 'SYS%';
    CURSOR prod_indexes IS SELECT index_name FROM ALL_INDEXES 
        WHERE OWNER = prod_schema_name AND index_name NOT LIKE 'SYS%';
    is_found BOOLEAN;
BEGIN
    FOR dev_index IN dev_indexes LOOP
        is_found := FALSE;
        FOR prod_index IN prod_indexes LOOP
            IF dev_index.index_name = prod_index.index_name THEN
                is_found := TRUE;
                EXIT;
            END IF;
        END LOOP;
        IF is_found = FALSE THEN
            DBMS_OUTPUT.PUT_LINE('Index ' || dev_index.index_name);
        END IF;
    END LOOP;
END;


CREATE OR REPLACE PROCEDURE compare_packages(dev_schema_name VARCHAR2, 
                                            prod_schema_name VARCHAR2)
AS
    CURSOR dev_packages IS SELECT object_name 
        FROM ALL_OBJECTS WHERE OBJECT_TYPE = 'PACKAGE'
        AND OWNER = dev_schema_name;
    CURSOR prod_packages IS SELECT object_name 
        FROM ALL_OBJECTS WHERE OBJECT_TYPE = 'PACKAGE'
        AND OWNER = prod_schema_name;
    package_is_found BOOLEAN;
    procedure_is_found BOOLEAN;    
BEGIN
    FOR dev_package IN dev_packages LOOP
        package_is_found := FALSE;
        FOR prod_package IN prod_packages LOOP
            IF dev_package.object_name = prod_package.object_name THEN
                package_is_found := TRUE;
                -- compare procedures
                procedure_is_found := FALSE;
                FOR dev_proc IN 
                (
                    SELECT procedure_name FROM ALL_PROCEDURES  WHERE OWNER = dev_schema_name 
                    AND object_name = dev_package.object_name 
                    AND procedure_name IS NOT NULL
                ) LOOP
                    FOR prod_proc IN 
                    (
                        SELECT procedure_name FROM ALL_PROCEDURES  WHERE OWNER = prod_schema_name 
                        AND object_name = prod_package.object_name 
                        AND procedure_name IS NOT NULL
                    ) LOOP
                        IF dev_proc.procedure_name = prod_proc.procedure_name THEN
                            procedure_is_found := TRUE;
                            -- compare procedures' arguments
                            IF have_different_arguments(dev_proc.procedure_name, 
                                                        dev_schema_name, 
                                                        prod_schema_name,
                                                        dev_package.object_name)
                            THEN
                                DBMS_OUTPUT.PUT_LINE('Different arguments in package '
                                    || dev_package.object_name || ' in function '
                                    || dev_proc.procedure_name);
                            END IF;
                            EXIT;
                        END IF;
                    END LOOP;
                    IF procedure_is_found = FALSE THEN
                        DBMS_OUTPUT.PUT_LINE('in package '
                                    || dev_package.object_name || ' function '
                                    || dev_proc.procedure_name);
                    END IF;
                END LOOP;
                IF have_different_text(dev_package.object_name, dev_schema_name, prod_schema_name, 'PACKAGE')
                    OR have_different_text(dev_package.object_name, dev_schema_name, prod_schema_name, 'PACKAGE BODY')
                THEN 
                    DBMS_OUTPUT.PUT_LINE('Package '
                                        || dev_package.object_name || 
                                        ' has different text');
                END IF;
                EXIT;
            END IF;
        END LOOP;
        IF package_is_found = FALSE THEN
            DBMS_OUTPUT.PUT_LINE('Package ' || dev_package.object_name);
        END IF;
    END LOOP;
END;







CREATE OR REPLACE FUNCTION have_different_text(object_name VARCHAR2, 
                                               dev_schema_name VARCHAR2, 
                                               prod_schema_name VARCHAR2,
                                               object_type VARCHAR2)
RETURN BOOLEAN
AS
    TYPE string_list_t IS TABLE OF VARCHAR2(300);
    dev_object_text string_list_t;
    prod_object_text string_list_t;
BEGIN
    SELECT text BULK COLLECT INTO dev_object_text 
        FROM ALL_SOURCE WHERE type = object_type
        AND name = object_name
        AND owner = dev_schema_name ORDER BY line;
    SELECT text BULK COLLECT INTO prod_object_text 
        FROM ALL_SOURCE WHERE type = object_type
        AND name = object_name
        AND owner = prod_schema_name ORDER BY line;
    IF dev_object_text.COUNT != prod_object_text.COUNT THEN
        RETURN TRUE;
    END IF;
    FOR i IN 1..dev_object_text.COUNT LOOP
        IF dev_object_text(i) != prod_object_text(i) THEN
            RETURN TRUE;
        END IF;
    END LOOP;
    RETURN FALSE;
END;


select * from all_source where NAME = 'EMP_MGMT' AND OWNER = 'DEV'
    order by TYPE, line;
    




CREATE OR REPLACE TYPE OBJECT_REC_TYPE AS OBJECT (
    object_type VARCHAR2(20),
    object_name VARCHAR(100),
    CONSTRUCTOR FUNCTION OBJECT_REC_TYPE RETURN SELF AS RESULT
);


CREATE OR REPLACE TYPE BODY OBJECT_REC_TYPE 
AS 
    CONSTRUCTOR FUNCTION OBJECT_REC_TYPE RETURN SELF AS RESULT
    IS
    BEGIN
        self.object_type := null;
        self.object_name := null;
        RETURN;
    END;
END;

 
CREATE OR REPLACE TYPE OBJECT_TABLE_TYPE AS TABLE OF OBJECT_REC_TYPE; 

SELECT * FROM ALL_INDEXES WHERE OWNER = 'DEV';


SELECT * FROM ALL_IND_COLUMNS WHERE INDEX_OWNER = 'DEV';


CREATE OR REPLACE FUNCTION update_prod_schema(dev_schema_name VARCHAR2, 
                                              prod_schema_name VARCHAR2)
RETURN VARCHAR2
AS
BEGIN
    get_differences(dev_schema_name, prod_schema_name); 
    get_differences(prod_schema_name, dev_schema_name); 
    RETURN 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
END;







-- TEST--
SET SERVEROUTPUT ON;
EXEC GET_DIFFERENCES('DEV', 'PROD');
EXEC GET_DIFFERENCES('PROD', 'DEV');


     
     