alter session set "_ORACLE_SCRIPT"=true;
create user prod identified by prod123 container=all;
grant all privileges to dev;
create user dev identified by dev123 container=all;
grant all privileges to prod;