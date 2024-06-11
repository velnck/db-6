

-- TEST--
SET SERVEROUTPUT ON;
EXEC GET_DIFFERENCES('DEV', 'PROD', TRUE);
EXEC GET_DIFFERENCES('PROD', 'DEV');


DECLARE
    ddl_script CLOB;
BEGIN
    ddl_script := get_full_ddl_script('DEV', 'PROD');
    DBMS_OUTPUT.PUT_LINE(ddl_script);
    
    
END;




create procedure dev.proc
as
 a number;
begin
 a := 5;
end;


create procedure prod.proc
as
 a number;
begin
 a := 6;
end;

truncate table different_objects;

drop procedure dev.proc;

exec compare_tables('DEV', 'PROD');

exec search_for_cyclic_references('T2', 'DEV');



create table dev.t1 (id number primary key, val number);
create table dev.t2 (id number primary key, val number);
create table dev.t3 (id number primary key, val number);


alter table dev.t1 drop constraint fk_t3;
alter table dev.t2 drop constraint fk_t1;
alter table dev.t3 drop constraint fk_t2;


ALTER TABLE dev.t3
  ADD CONSTRAINT fk_t1 
  FOREIGN KEY (val)
  REFERENCES dev.t1(id);
  
ALTER TABLE dev.t2
  ADD CONSTRAINT fk_t3 
  FOREIGN KEY (val)
  REFERENCES dev.t3(id);
  

ALTER TABLE dev.t1
  ADD CONSTRAINT fk_t2 
  FOREIGN KEY (val)
  REFERENCES dev.t2(id);
  
  
drop table dev.t2;


     
     