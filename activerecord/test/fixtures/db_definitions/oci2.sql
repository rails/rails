create sequence rails_sequence minvalue 10000;

create table courses (
  id int not null primary key,
  name varchar(255) not null
);
