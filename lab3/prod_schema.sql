CREATE TABLE prod.departments( 
  department_id number(10) NOT NULL PRIMARY KEY,
  department_name varchar2(50) NOT NULL
); 

CREATE TABLE prod.employees(
  employee_number number(10) NOT NULL PRIMARY KEY,
  employee_name varchar2(50) NOT NULL,
  department_id number(10),
  salary number(6),
  CONSTRAINT fk_departments
    FOREIGN KEY (department_id)
    REFERENCES prod.departments(department_id)
);

CREATE TABLE prod.a1(
    x number,
    y number
);

create index prod.a1_index on prod.a1(x, y);

create index prod.a1_x_index on prod.a1(x);

ALTER TABLE prod.departments
  ADD departemnt_mystery varchar2(45);
  
  
CREATE TABLE prod.test_constr(
    id number NOT NULL PRIMARY KEY
);


CREATE OR REPLACE PROCEDURE prod.greetings 
AS 
BEGIN 

   dbms_output.put_line('Hello World!'); 
   
END; 

CREATE OR REPLACE FUNCTION prod.find_sum_1(number_1 NUMBER) 
RETURN NUMBER 
IS
    sum_ NUMBER;
BEGIN
    sum_ := number_1;
    return sum_;
END;

CREATE OR REPLACE FUNCTION prod.find_sum(number_1 NUMBER, number_2 NUMBER) 
    RETURN NUMBER 
    IS
    sum_ NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('result');
        sum_ := number_1 + number_2;
        return sum_;
    END;
    
create table n1(
    x number primary key,
     y number
);
ALTER TABLE a1
  ADD z number primary key;
  
create table n2(
    x1 number primary key,
    y1 number,
    z1 number,
    x1_ref number,
    CONSTRAINT x1_ref_name
    FOREIGN KEY (x1_ref)
    REFERENCES a1(z)
);   

CREATE TABLE prod.HI(
    str VARCHAR2(15)
);
