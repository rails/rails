CREATE TABLE accounts (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  firm_id int default NULL,
  credit_limit int default NULL
);

CREATE TABLE funny_jokes (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name varchar(50) default NULL
);

CREATE TABLE companies (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  type varchar(50) default NULL,
  ruby_type varchar(50) default NULL,
  firm_id int default NULL,
  name varchar(50) default NULL,
  client_of int default NULL,
  rating int default 1
);

CREATE TABLE topics (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  title varchar(255) default NULL,
  author_name varchar(255) default NULL,
  author_email_address varchar(255) default NULL,
  written_on datetime default NULL,
  bonus_time datetime default NULL,
  last_read datetime default NULL,
  content varchar(255) default NULL,
  approved bit default 1,
  replies_count int default 0,
  parent_id int default NULL,
  type varchar(50) default NULL
);

CREATE TABLE developers (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name varchar(100) default NULL,
  salary int default 70000,
  created_at datetime default NULL,
  updated_at datetime default NULL
);

CREATE TABLE projects (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name varchar(100) default NULL,
  type varchar(255) default NULL
);

CREATE TABLE developers_projects (
  developer_id int NOT NULL,
  project_id int NOT NULL,
  joined_on datetime default NULL,
  access_level int default 1
);

CREATE TABLE orders (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name varchar(100) default NULL,
  billing_customer_id int default NULL,
  shipping_customer_id int default NULL
);


CREATE TABLE customers (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name varchar(100) default NULL,
  balance int default 0,
  address_street varchar(100) default NULL,
  address_city varchar(100) default NULL,
  address_country varchar(100) default NULL,
  gps_location varchar(100) default NULL
);

CREATE TABLE movies (
  movieid int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name varchar(100) default NULL
);

CREATE TABLE subscribers (
  nick varchar(100) NOT NULL PRIMARY KEY,
  name varchar(100) default NULL
);

CREATE TABLE booleantests (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  value bit default NULL
);

CREATE TABLE defaults (
    id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
-- these brought from the PostgreSQL defaults_test.rb but
-- tests only exist for integers and decimals, currently
--    modified_date date default CURRENT_DATE,
--    modified_date_function date default now(),
--    fixed_date date default '2004-01-01',
--    modified_time timestamp default CURRENT_TIMESTAMP,
--    modified_time_function timestamp default now(),
--    fixed_time timestamp default '2004-01-01 00:00:00.000000-00',
--    char1 char(1) default 'Y',
--    char2 character varying(50) default 'a varchar field',
--    char3 text default 'a text field',
    positive_integer integer default 1,
    negative_integer integer default -1,
    decimal_number decimal(3,2) default 2.78
);

CREATE TABLE auto_id_tests (
  auto_id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  value int default NULL
);

CREATE TABLE entrants (
  id int NOT NULL PRIMARY KEY,
  name varchar(255) NOT NULL,
  course_id int NOT NULL
);

CREATE TABLE colnametests (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  [references] int NOT NULL
);

CREATE TABLE mixins (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  parent_id int default NULL, 
  pos int default NULL,
  created_at datetime default NULL,
  updated_at datetime default NULL,
  lft int default NULL,
  rgt int default NULL,
  root_id int default NULL,
  type varchar(40) default NULL    
);

CREATE TABLE people (
  id int NOT NULL IDENTITY(1, 1),
  first_name varchar(40) NULL,
  lock_version int default 0,
  PRIMARY KEY (id)
);

CREATE TABLE readers (
    id int NOT NULL IDENTITY(1, 1),
    post_id int NOT NULL,
    person_id int NOT NULL,
    primary key (id)
);

CREATE TABLE binaries (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  data image NULL
);

CREATE TABLE computers (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  developer int NOT NULL,
  extendedWarranty int NOT NULL
);

CREATE TABLE posts (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  author_id int default NULL,
  title varchar(255) default NULL,
  type varchar(255) default NULL,
  body varchar(4096) default NULL
);

CREATE TABLE comments (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  post_id int default NULL,
  type varchar(255) default NULL,
  body varchar(4096) default NULL
);

CREATE TABLE authors (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name varchar(255) default NULL
);

CREATE TABLE tasks (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  starting datetime default NULL,
  ending datetime default NULL
);

CREATE TABLE categories (
  id int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name varchar(255),
  type varchar(255) default NULL
);

CREATE TABLE categories_posts (
  category_id int NOT NULL,
  post_id int NOT NULL
);

CREATE TABLE fk_test_has_pk (
  id INTEGER NOT NULL PRIMARY KEY
);

CREATE TABLE fk_test_has_fk (
  id    INTEGER NOT NULL PRIMARY KEY,
  fk_id INTEGER NOT NULL,

  FOREIGN KEY (fk_id) REFERENCES fk_test_has_pk(id)
);

CREATE TABLE keyboards (
  key_number int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  name varchar(50) default NULL
);

--This table has an altered lock_version column name.
CREATE TABLE legacy_things (
  id int NOT NULL IDENTITY(1, 1),
  tps_report_number int default NULL,
  version int default 0,
  PRIMARY KEY (id)
);

CREATE TABLE numeric_data (
  id int NOT NULL IDENTITY(1, 1),
  bank_balance decimal(10,2),
  big_bank_balance decimal(15,2),
  world_population decimal(10),
  my_house_population decimal(2),
  decimal_number_with_default decimal(3,2) DEFAULT 2.78
);
