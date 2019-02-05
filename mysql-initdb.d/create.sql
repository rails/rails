create user rails@'%';
grant all privileges on activerecord_unittest.* to rails@'%';
grant all privileges on activerecord_unittest2.* to rails@'%';
grant all privileges on inexistent_activerecord_unittest.* to rails@'%';
create database activerecord_unittest default character set utf8mb4;
create database activerecord_unittest2 default character set utf8mb4;
