CREATE TABLE dev.users(
    person_id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL
);

CREATE TABLE dev.departments( 
  department_id number(10) NOT NULL PRIMARY KEY,
  department_name varchar2(50) NOT NULL
);

CREATE TABLE dev.employees(
  employee_number number(10) NOT NULL PRIMARY KEY,
  employee_name varchar2(50) NOT NULL,
  department_id number(10),
  salary number(6),
  CONSTRAINT fk_departments
    FOREIGN KEY (department_id)
    REFERENCES dev.departments(department_id)
);

ALTER TABLE dev.departments
  ADD (departemnt_mystery varchar2(45),
       counter NUMBER);
       
CREATE TABLE dev.test_constr(
    id number NOT NULL PRIMARY KEY,
     department_id number,
     CONSTRAINT fk_departments_test
    FOREIGN KEY (department_id)
    REFERENCES dev.departments(department_id)
);

CREATE OR REPLACE PROCEDURE dev.greetings 
AS 
BEGIN 
   dbms_output.put_line('Hello World!'); 
END; 

CREATE OR REPLACE PROCEDURE dev.greetings_with_argument(name_arg VARCHAR)
AS 
BEGIN 
   dbms_output.put_line('Hello, ' || name_arg || '!'); 
END;

CREATE OR REPLACE PACKAGE dev.emp_mgmt AS
    FUNCTION hire(last_name VARCHAR2, job_id VARCHAR2, manager_id NUMBER, 
    salary NUMBER, commission_pct NUMBER, department_id NUMBER) RETURN NUMBER;
    END emp_mgmt;

CREATE OR REPLACE PACKAGE BODY dev.emp_mgmt AS 
    empl_num NUMBER;
    FUNCTION hire(last_name VARCHAR2, job_id VARCHAR2, manager_id NUMBER, 
    salary NUMBER, commission_pct NUMBER, department_id NUMBER) RETURN NUMBER IS new_empl NUMBER;
    BEGIN
        return 13;
    END;
END emp_mgmt;

CREATE OR REPLACE FUNCTION dev.find_sum(number_1 NUMBER, number_2 NUMBER) 
    RETURN NUMBER 
    IS
    sum_ NUMBER;
    BEGIN
        sum_ := number_1 + number_2;
        return sum_;
    END;
    
CREATE OR REPLACE FUNCTION dev.find_sum_3(number_1 NUMBER, number_2 NUMBER, number_3 NUMBER) 
    RETURN NUMBER 
    IS
    sum_ NUMBER;
    BEGIN
        sum_ := number_1 + number_2 + number_3;
        return sum_;
    END;
    
CREATE TABLE dev.my_table(
    name VARCHAR2(10)
);

CREATE TABLE dev.a1(
    x number,
    y number
);

create index dev.a3_index on dev.a1(y);
create index dev.a2_index on dev.a1(x,y);
create index dev.a1_index on dev.a1(x);

create table dev.n1(
    x number primary key,
    y number
);
  
create table dev.n2(
    x1 number primary key,
    y1 number,
    z1 number,
    x1_ref number,
    CONSTRAINT x1_ref_name
    FOREIGN KEY (x1_ref)
    REFERENCES dev.n1(x)
);

ALTER TABLE dev.n1
  ADD CONSTRAINT x1_ref_n1
    FOREIGN KEY (y)
    REFERENCES dev.n2(x1);

CREATE TABLE dev.n3(
    x1 number primary key,
    n1_ref number,
    CONSTRAINT fk_n1
    FOREIGN KEY (n1_ref)
    REFERENCES dev.n1(x)
);

ALTER TABLE dev.n1
  ADD n3_ref NUMBER;
    
ALTER TABLE dev.n1
  ADD CONSTRAINT fk_n3 
  FOREIGN KEY (n3_ref)
  REFERENCES dev.n3(x1);
  
CREATE OR REPLACE FUNCTION dev.func_differrent_arguments(arg1 NUMBER, arg2 VARCHAR2)
RETURN NUMBER
AS
BEGIN
    RETURN arg1;
END;

CREATE OR REPLACE PACKAGE dev.different_source_text AS
    FUNCTION f1 RETURN NUMBER;
    END different_source_text;

CREATE OR REPLACE PACKAGE BODY dev.different_source_text AS 
    FUNCTION f1 RETURN NUMBER IS
    BEGIN
        return 13;
    END;
END different_source_text;
