CREATE TABLE accounts (
  id int NOT NULL,
  firm_id int default NULL,
  credit_limit int default NULL,
  PRIMARY KEY (id)
);
CREATE SEQUENCE accounts_id MINVALUE 10000;

CREATE TABLE companies (
  id int NOT NULL,
  type varchar(50) default NULL,
  ruby_type varchar(50) default NULL,
  firm_id int default NULL,
  name varchar(50) default NULL,
  client_of int default NULL,
  rating int default 1,
  PRIMARY KEY (id)
);
CREATE SEQUENCE companies_id MINVALUE 10000;

CREATE TABLE topics (
  id int NOT NULL,
  title varchar(255) default NULL,
  author_name varchar(255) default NULL,
  author_email_address varchar(255) default NULL,
  written_on timestamp default NULL,
  bonus_time timestamp default NULL,
  last_read date default NULL,
  content varchar(3000),
  approved smallint default 1,
  replies_count int default 0,
  parent_id int default NULL,
  type varchar(50) default NULL,
  PRIMARY KEY (id)
);
CREATE SEQUENCE topics_id MINVALUE 10000;

CREATE TABLE developers (
  id int NOT NULL,
  name varchar(100) default NULL,
  salary int default 70000,
  PRIMARY KEY (id)
);
CREATE SEQUENCE developers_id MINVALUE 10000;

CREATE TABLE projects (
  id int NOT NULL,
  name varchar(100) default NULL,
  PRIMARY KEY (id)
);
CREATE SEQUENCE projects_id MINVALUE 10000;

CREATE TABLE developers_projects (
  developer_id int NOT NULL,
  project_id int NOT NULL,
  joined_on date default NULL
);
CREATE SEQUENCE developers_projects_id MINVALUE 10000;

CREATE TABLE customers (
  id int NOT NULL,
  name varchar(100) default NULL,
  balance int default 0,
  address_street varchar(100) default NULL,
  address_city varchar(100) default NULL,
  address_country varchar(100) default NULL,
  PRIMARY KEY (id)
);
CREATE SEQUENCE customers_id MINVALUE 10000;

CREATE TABLE movies (
  movieid int NOT NULL,
  name varchar(100) default NULL,
  PRIMARY KEY (movieid)
);
CREATE SEQUENCE movies_id MINVALUE 10000;

CREATE TABLE subscribers (
  nick varchar(100) NOT NULL,
  name varchar(100) default NULL,
  PRIMARY KEY (nick)
);
CREATE SEQUENCE subscribers_id MINVALUE 10000;

CREATE TABLE booleantests (
  id int NOT NULL,
  value int default NULL,
  PRIMARY KEY (id)
);
CREATE SEQUENCE booleantests_id MINVALUE 10000;

CREATE TABLE auto_id_tests (
  auto_id int NOT NULL,
  value int default NULL,
  PRIMARY KEY (auto_id)
);
CREATE SEQUENCE auto_id_tests_id MINVALUE 10000;

CREATE TABLE entrants (
  id int NOT NULL PRIMARY KEY,
  name varchar(255) NOT NULL,
  course_id int NOT NULL
);
CREATE SEQUENCE entrants_id MINVALUE 10000;

CREATE TABLE colnametests (
  id int NOT NULL,
  references int NOT NULL,
  PRIMARY KEY (id)
);
CREATE SEQUENCE colnametests_id MINVALUE 10000;

CREATE TABLE mixins (
  id int NOT NULL,
  parent_id int default NULL,
  pos int default NULL,
  created_at timestamp default NULL,
  updated_at timestamp default NULL,
  lft int default NULL,
  rgt int default NULL,
  root_id int default NULL,
  type varchar(40) default NULL,
  PRIMARY KEY (id)
);
CREATE SEQUENCE mixins_id MINVALUE 10000;

CREATE TABLE people (
  id int NOT NULL,
  first_name varchar(40) NOT NULL,
  lock_version int default 0,
  PRIMARY KEY  (id)
);
CREATE SEQUENCE people_id MINVALUE 10000;

CREATE TABLE binaries (
  id int NOT NULL,
  data blob,
  PRIMARY KEY  (id)
);
CREATE SEQUENCE binaries_id MINVALUE 10000;

CREATE TABLE computers (
  id int,
  developer int NOT NULL,
  PRIMARY KEY (id)
);
CREATE SEQUENCE computers_id MINVALUE 10000;

EXIT;
