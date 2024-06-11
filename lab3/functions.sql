CREATE TABLE different_objects (
    name VARCHAR2(100) NOT NULL,
    type VARCHAR2(20) NOT NULL,
    description VARCHAR2(100)
);


CREATE OR REPLACE PROCEDURE compare_tables(dev_schema_name VARCHAR2, 
                                           prod_schema_name VARCHAR2,
                                           search_for_cycles BOOLEAN DEFAULT TRUE)
AUTHID CURRENT_USER
AS
    TYPE tables_t IS TABLE OF VARCHAR2(100);
    dev_tables tables_t;
    prod_tables tables_t;
    
    is_found BOOLEAN := FALSE;
BEGIN
    SELECT dev_t.OBJECT_NAME BULK COLLECT INTO dev_tables FROM 
    (
        (SELECT TABLE_NAME OBJECT_NAME FROM ALL_TABLES WHERE OWNER = dev_schema_name) dev_t
        LEFT JOIN 
        (SELECT OBJECT_NAME, CREATED CREATED_IN_PROD FROM ALL_OBJECTS 
        WHERE OBJECT_TYPE = 'TABLE' AND OWNER = prod_schema_name) prod_t
        ON dev_t.OBJECT_NAME = prod_t.OBJECT_NAME
    ) ORDER BY CREATED_IN_PROD ASC;
    SELECT OBJECT_NAME BULK COLLECT INTO prod_tables
        FROM ALL_OBJECTS WHERE OBJECT_TYPE = 'TABLE' 
        AND OWNER = prod_schema_name;
    FOR i IN 1..dev_tables.COUNT LOOP
        is_found := FALSE;
        FOR i_prod IN 1..prod_tables.COUNT LOOP
            IF prod_tables(i_prod) = dev_tables(i) THEN
                is_found := TRUE;
                IF have_different_structure(dev_tables(i), dev_schema_name, prod_schema_name) THEN
                    INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                        VALUES (dev_tables(i), 'TABLE', 'STRUCTURE');
                ELSIF have_different_constraints(dev_tables(i), dev_schema_name, prod_schema_name) THEN
                    INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                        VALUES (dev_tables(i), 'TABLE', 'CONSTRAINTS');
                END IF;
                EXIT;
            END IF;
        END LOOP; 
        IF is_found = FALSE THEN          
            INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                VALUES (dev_tables(i), 'TABLE', 'NOT EXISTS');
        END IF;
    END LOOP;
    
    IF search_for_cycles THEN
        FOR i IN 1..dev_tables.COUNT LOOP
            search_for_cyclic_references(dev_tables(i), dev_schema_name);
        END LOOP;
        FOR i IN 1..prod_tables.COUNT LOOP
            search_for_cyclic_references(prod_tables(i), prod_schema_name);
        END LOOP;
    END IF;
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
            REGEXP_SUBSTR(cycle_row.references_path, '[^ ]+', 1, 1) || '$') = true -- the first table in cycle is equal to the last
        THEN
            DBMS_OUTPUT.PUT_LINE('Detected cycle: ' || cycle_row.references_path 
                    || ' (schema: ''' || schema_name || ''').');
            END IF;
    END LOOP;
END;


CREATE OR REPLACE PROCEDURE compare_functions(dev_schema_name VARCHAR2, 
                                              prod_schema_name VARCHAR2)
AUTHID CURRENT_USER
AS
    TYPE func_record_t IS RECORD 
    (
        OBJECT_NAME ALL_OBJECTS.OBJECT_NAME%TYPE,
        OBJECT_TYPE ALL_OBJECTS.OBJECT_TYPE%TYPE
    );
    TYPE funcs_table_t IS TABLE OF func_record_t;
    dev_funcs funcs_table_t;
    prod_funcs funcs_table_t;
    is_found BOOLEAN := FALSE;
BEGIN
    SELECT DEV_T.OBJECT_NAME, OBJECT_TYPE BULK COLLECT INTO dev_funcs FROM 
        (
            (
                SELECT OBJECT_NAME, OBJECT_TYPE
                FROM ALL_OBJECTS WHERE OBJECT_TYPE IN ('PROCEDURE', 'FUNCTION')
                AND OWNER = dev_schema_name
            ) dev_t
            LEFT JOIN 
            (
                SELECT OBJECT_NAME, CREATED CREATED_IN_PROD
                FROM ALL_OBJECTS WHERE OBJECT_TYPE IN ('PROCEDURE', 'FUNCTION')
                AND OWNER = prod_schema_name
            ) prod_t
            ON dev_t.OBJECT_NAME = prod_t.OBJECT_NAME
        ) ORDER BY CREATED_IN_PROD ASC;
    SELECT OBJECT_NAME, OBJECT_TYPE BULK COLLECT INTO prod_funcs 
        FROM ALL_OBJECTS WHERE OBJECT_TYPE IN ('PROCEDURE', 'FUNCTION') 
        AND OWNER = prod_schema_name ORDER BY CREATED ASC;
    FOR i_dev IN 1..dev_funcs.COUNT LOOP
        is_found := FALSE;
        FOR i_prod IN 1..prod_funcs.COUNT LOOP
            IF prod_funcs(i_prod).OBJECT_NAME = dev_funcs(i_dev).OBJECT_NAME THEN
                is_found := TRUE;
                IF have_different_arguments(dev_funcs(i_dev).OBJECT_NAME, dev_schema_name, prod_schema_name, NULL) THEN
                    INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                        VALUES (dev_funcs(i_dev).OBJECT_NAME, dev_funcs(i_dev).OBJECT_TYPE, 'ARGUMENTS');
                ELSIF have_different_text(dev_funcs(i_dev).OBJECT_NAME, dev_schema_name, prod_schema_name, dev_funcs(i_dev).object_type) THEN
                    INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                        VALUES (dev_funcs(i_dev).OBJECT_NAME, dev_funcs(i_dev).OBJECT_TYPE, 'TEXT');
                END IF;
                EXIT;
            END IF;
        END LOOP; 
        IF is_found = FALSE THEN 
            INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                        VALUES (dev_funcs(i_dev).OBJECT_NAME, dev_funcs(i_dev).OBJECT_TYPE, 'NOT EXISTS');
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
AUTHID CURRENT_USER
AS
    TYPE index_record_t IS RECORD 
    (
        index_name ALL_INDEXES.index_name%TYPE,
        table_name ALL_INDEXES.table_name%TYPE
    );
    TYPE indexes_table_t IS TABLE OF index_record_t;
    dev_indexes indexes_table_t;
    prod_indexes indexes_table_t;
    is_found BOOLEAN;
    TYPE string_list_t IS TABLE OF VARCHAR2(300);
    dev_index_columns string_list_t;
    prod_index_columns string_list_t;
BEGIN
     SELECT index_name, table_name BULK COLLECT INTO dev_indexes FROM ALL_INDEXES 
        WHERE OWNER = dev_schema_name AND index_name NOT LIKE 'SYS%';
    SELECT index_name, table_name BULK COLLECT INTO prod_indexes FROM ALL_INDEXES 
        WHERE OWNER = prod_schema_name AND index_name NOT LIKE 'SYS%';
    FOR i_dev IN 1..dev_indexes.COUNT LOOP
        is_found := FALSE;
       FOR i_prod IN 1..prod_indexes.COUNT LOOP
            IF dev_indexes(i_dev).index_name = prod_indexes(i_prod).index_name THEN
                is_found := TRUE;
                IF dev_indexes(i_dev).table_name != prod_indexes(i_prod).table_name THEN
                    INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                        VALUES (dev_indexes(i_dev).index_name, 'INDEX', 'TABLES');
                    EXIT;
                END IF;
                SELECT column_name BULK COLLECT INTO dev_index_columns
                    FROM ALL_IND_COLUMNS WHERE index_owner = dev_schema_name 
                    AND index_name = dev_indexes(i_dev).index_name ORDER BY column_position;
                SELECT column_name BULK COLLECT INTO prod_index_columns
                    FROM ALL_IND_COLUMNS WHERE index_owner = prod_schema_name 
                    AND index_name = dev_indexes(i_dev).index_name ORDER BY column_position;
                IF dev_index_columns.COUNT != prod_index_columns.COUNT THEN
                    INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                        VALUES (dev_indexes(i_dev).index_name, 'INDEX', 'COLUMNS');
                    EXIT;
                END IF;
                FOR i IN 1..dev_index_columns.COUNT LOOP
                    IF dev_index_columns(i) != prod_index_columns(i) THEN
                        INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                            VALUES (dev_indexes(i_dev).index_name, 'INDEX', 'COLUMNS');
                        EXIT;
                    END IF;
                END LOOP;
                EXIT;
            END IF;
        END LOOP;
        IF is_found = FALSE THEN
            INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                        VALUES (dev_indexes(i_dev).index_name, 'INDEX', 'NOT EXISTS');
        END IF;
    END LOOP;
END;


CREATE OR REPLACE PROCEDURE compare_packages(dev_schema_name VARCHAR2, 
                                            prod_schema_name VARCHAR2)
AUTHID CURRENT_USER
AS
    TYPE packages_t IS TABLE OF VARCHAR2(100);
    dev_packages packages_t;
    prod_packages packages_t;
    package_is_found BOOLEAN;   
BEGIN
    SELECT object_name BULK COLLECT INTO dev_packages
        FROM ALL_OBJECTS WHERE OBJECT_TYPE = 'PACKAGE'
        AND OWNER = dev_schema_name;
    SELECT object_name BULK COLLECT INTO prod_packages  
        FROM ALL_OBJECTS WHERE OBJECT_TYPE = 'PACKAGE'
        AND OWNER = prod_schema_name;
    FOR i_dev IN 1..dev_packages.COUNT LOOP
        package_is_found := FALSE;
        FOR i_prod IN 1..prod_packages.COUNT LOOP
            IF dev_packages(i_dev) = prod_packages(i_prod) THEN
                package_is_found := TRUE;
                IF have_different_text(dev_packages(i_dev), dev_schema_name, prod_schema_name, 'PACKAGE')
                    OR have_different_text(dev_packages(i_dev), dev_schema_name, prod_schema_name, 'PACKAGE BODY')
                THEN 
                    INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                        VALUES (dev_packages(i_dev), 'PACKAGE', 'TEXT');
                END IF;
                EXIT;
            END IF;
        END LOOP;
        IF package_is_found = FALSE THEN
            INSERT INTO DIFFERENT_OBJECTS (name, type, description)
                        VALUES (dev_packages(i_dev), 'PACKAGE', 'NOT EXISTS');
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


CREATE OR REPLACE PROCEDURE get_differences(dev_schema_name VARCHAR2, 
                                            prod_schema_name VARCHAR2,
                                            search_for_cycles BOOLEAN)
AUTHID CURRENT_USER
AS
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE different_objects';
    compare_tables(dev_schema_name, prod_schema_name, search_for_cycles);
    compare_functions(dev_schema_name, prod_schema_name);
    compare_indexes(dev_schema_name, prod_schema_name);
    compare_packages(dev_schema_name, prod_schema_name);
END;


CREATE OR REPLACE FUNCTION get_full_ddl_script(dev_schema_name VARCHAR2, 
                                                prod_schema_name VARCHAR2)
RETURN CLOB
AUTHID CURRENT_USER
AS
    ddl_script CLOB;
BEGIN
    ddl_script := '';
--    get_differences(dev_schema_name, prod_schema_name, TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(dbms_metadata.SESSION_TRANSFORM, 'EMIT_SCHEMA', false);
    FOR rec IN (SELECT * FROM DIFFERENT_OBJECTS) LOOP
        IF rec.description = 'NOT EXISTS' THEN
            ddl_script := ddl_script || get_create_ddl_script(rec.type, rec.name, dev_schema_name);
        ELSE
            ddl_script := ddl_script || get_drop_ddl_script(rec.type, rec.name, prod_schema_name);
            ddl_script := ddl_script || get_create_ddl_script(rec.type, rec.name, dev_schema_name);
        END IF;
    END LOOP;
    
--    get_differences(prod_schema_name, dev_schema_name, FALSE);
    FOR rec IN (SELECT * FROM DIFFERENT_OBJECTS) LOOP
        IF rec.description = 'NOT EXISTS' THEN
            ddl_script := ddl_script || get_drop_ddl_script(rec.type, rec.name, prod_schema_name);
        END IF;
    END LOOP;
    RETURN ddl_script;
END;


CREATE OR REPLACE FUNCTION get_create_ddl_script(object_type VARCHAR2, 
                                                  object_name VARCHAR2, 
                                                  schema_name VARCHAR2)
RETURN CLOB
AUTHID CURRENT_USER
AS
    ddl_script CLOB;
BEGIN
    IF object_type = 'TABLE' THEN
        ddl_script := DBMS_METADATA.GET_DDL('TABLE', object_name, schema_name);
    ELSIF object_type = 'FUNCTION' THEN
        ddl_script := DBMS_METADATA.GET_DDL('FUNCTION', object_name, schema_name);    
    ELSIF object_type = 'PROCEDURE' THEN
        ddl_script := DBMS_METADATA.GET_DDL('PROCEDURE', object_name, schema_name);
    ELSIF object_type = 'PACKAGE' THEN
        ddl_script := DBMS_METADATA.GET_DDL('PACKAGE', object_name, schema_name);
    ELSIF object_type = 'INDEX' THEN
        ddl_script := DBMS_METADATA.GET_DDL('INDEX', object_name, schema_name);
    END IF;
    RETURN ddl_script;
END;


CREATE OR REPLACE FUNCTION get_drop_ddl_script(object_type VARCHAR2, 
                                                object_name VARCHAR2, 
                                                schema_name VARCHAR2)
RETURN CLOB
AUTHID CURRENT_USER
AS
    ddl_script CLOB;
BEGIN
    IF object_type = 'TABLE' THEN
        ddl_script := CHR(13) || 'DROP TABLE ' || schema_name || '.' || object_name || ' CASCADE CONSTRAINTS;';
    ELSIF object_type = 'FUNCTION' THEN
        ddl_script := CHR(13) || 'DROP FUNCTION ' || schema_name || '.' || object_name || ';';
    ELSIF object_type = 'PROCEDURE' THEN
        ddl_script := CHR(13) || 'DROP PROCEDURE ' || schema_name || '.' || object_name || ';';
    ELSIF object_type = 'PACKAGE' THEN
        ddl_script := CHR(13) || 'DROP PACKAGE ' || schema_name || '.' || object_name || ';';
    ELSIF object_type = 'INDEX' THEN
        ddl_script := CHR(13) || 'DROP INDEX ' || schema_name || '.' || object_name || ';';
    END IF;
    RETURN ddl_script;
END;
