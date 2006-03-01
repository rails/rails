create table courses (
  id int not null primary key,
  name varchar(255) not null
);

create sequence courses_seq minvalue 10000;
