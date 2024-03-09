-------------------------------------------
-- 1
-------------------------------------------

CREATE TABLE students (
    id NUMBER,
    name VARCHAR2(100) NOT NULL,
    group_id NUMBER
);

CREATE TABLE groups (
    id NUMBER,
    name VARCHAR2(10) NOT NULL,
    c_val NUMBER NOT NULL
);

-------------------------------------------
-- 2
-------------------------------------------

CREATE SEQUENCE students_id_seq START WITH 1;
CREATE OR REPLACE TRIGGER get_students_id
BEFORE INSERT ON students
FOR EACH ROW
WHEN (NEW.id IS NULL)
DECLARE
    cnt NUMBER;
BEGIN
    :NEW.id := students_id_seq.NEXTVAL;
    SELECT COUNT(id) INTO cnt FROM students WHERE ID = :NEW.id;
    WHILE (cnt > 0) LOOP
        :NEW.id := students_id_seq.NEXTVAL;
        SELECT COUNT(id) INTO cnt FROM students WHERE ID = :NEW.id;
    END LOOP;
END;

CREATE SEQUENCE groups_id_seq START WITH 1;
CREATE OR REPLACE TRIGGER get_groups_id
BEFORE INSERT ON groups
FOR EACH ROW
WHEN (NEW.id IS NULL)
DECLARE
    cnt NUMBER;
BEGIN
    :NEW.id := groups_id_seq.NEXTVAL;
    SELECT COUNT(id) INTO cnt FROM groups WHERE ID = :NEW.id;
    WHILE (cnt > 0) LOOP
        :NEW.id := groups_id_seq.NEXTVAL;
        SELECT COUNT(id) INTO cnt FROM groups WHERE ID = :NEW.id;
    END LOOP;
END;

CREATE OR REPLACE TRIGGER check_unique_students_id_insert
BEFORE INSERT
ON students FOR EACH ROW
FOLLOWS get_students_id
DECLARE
    id_ NUMBER;
    id_exists EXCEPTION;
BEGIN
    SELECT students.id INTO id_ FROM students WHERE students.id = :NEW.id;
    dbms_output.put_line('ID already exists.');
    raise id_exists;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('Successfully inserted.');
END;

CREATE OR REPLACE TRIGGER check_unique_students_id_update
AFTER UPDATE
ON students
DECLARE
    total_count NUMBER;
    distinct_count NUMBER;
    id_exists EXCEPTION;
BEGIN
    SELECT COUNT(id), COUNT(DISTINCT id)
        INTO total_count, distinct_count FROM students;
    IF total_count > distinct_count THEN
        dbms_output.put_line('ID already exists.');
        raise id_exists;
    ELSE 
        dbms_output.put_line('Successfully inserted.');
    END IF;
END;

CREATE OR REPLACE TRIGGER check_unique_groups_values_insert
BEFORE INSERT
ON groups FOR EACH ROW
FOLLOWS get_groups_id
DECLARE
    id_ NUMBER;
    name_ VARCHAR2(100);
    not_unique EXCEPTION;
BEGIN
    SELECT groups.id, groups.name INTO id_, name_ FROM groups 
        WHERE groups.id = :NEW.id OR groups.name = :NEW.name;
    dbms_output.put_line('ID or name already exists.');
    raise not_unique;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        dbms_output.put_line('Successfully inserted.');
END;

CREATE OR REPLACE TRIGGER check_unique_groups_values_update
AFTER UPDATE
ON groups
DECLARE
    total_count NUMBER;
    distinct_id_count NUMBER;
    distinct_name_count NUMBER;
    id_exists EXCEPTION;
    name_exists EXCEPTION;
BEGIN
    SELECT COUNT(id), COUNT(DISTINCT id), COUNT(DISTINCT name)
        INTO total_count, distinct_id_count, distinct_name_count 
        FROM groups;
    IF total_count > distinct_id_count THEN
        dbms_output.put_line('ID already exists.');
        raise id_exists;
    ELSIF total_count > distinct_name_count THEN
        dbms_output.put_line('Name already exists.');
        raise name_exists;
    ELSE 
        dbms_output.put_line('Successfully inserted.');
    END IF;
END;

INSERT INTO groups(name, c_val) VALUES('01', 0);
INSERT INTO groups(name, c_val) VALUES('02', 0);
INSERT INTO groups(name, c_val) VALUES('03', 0);
INSERT INTO groups(name, c_val) VALUES('04', 0);
INSERT INTO groups(name, c_val) VALUES('06', 0);

INSERT INTO students (name, group_id) VALUES ('Melissa', 2);
INSERT INTO students (name, group_id) VALUES ('Alex', 1);
INSERT INTO students (name, group_id) VALUES ('Nat', 2);
INSERT INTO students (name, group_id) VALUES ('Ash', 3);
INSERT INTO students (name, group_id) VALUES ('Niall', 5);
INSERT INTO students (name, group_id) VALUES ('Joy', 5);
INSERT INTO students (name, group_id) VALUES ('Jeremy', 1);
INSERT INTO students (name, group_id) VALUES ('Mattew', 3);



