CREATE TABLE accounts (
    id integer UNIQUE INDEX DEFAULT _rowid,
    firm_id integer,
    credit_limit integer
)
go
CREATE PRIMARY KEY accounts (id) 
go

CREATE TABLE funny_jokes (
  id integer UNIQUE INDEX DEFAULT _rowid,
  name char(50) DEFAULT NULL
)
go
CREATE PRIMARY KEY funny_jokes (id)
go

CREATE TABLE companies (
    id integer UNIQUE INDEX DEFAULT _rowid,
    type char(50),
    ruby_type char(50),
    firm_id integer,
    name char(50),
    client_of integer,
    rating integer default 1
) 
go
CREATE PRIMARY KEY companies (id) 
go

CREATE TABLE developers_projects (
    developer_id integer NOT NULL,
    project_id integer NOT NULL,
    joined_on date,
    access_level integer default 1
) 
go

CREATE TABLE developers (
    id integer UNIQUE INDEX DEFAULT _rowid,
    name char(100),
    salary integer DEFAULT 70000,
    created_at datetime,
    updated_at datetime
) 
go
CREATE PRIMARY KEY developers (id) 
go

CREATE TABLE projects (
    id integer UNIQUE INDEX DEFAULT _rowid,
    name char(100),
    type char(255)
) 
go
CREATE PRIMARY KEY projects (id) 
go

CREATE TABLE topics (
    id integer UNIQUE INDEX DEFAULT _rowid,
    title char(255),
    author_name char(255),
    author_email_address char(255),
    written_on datetime,
    bonus_time time,
    last_read date,
    content char(4096),
    approved boolean default true,
    replies_count integer default 0,
    parent_id integer,
    type char(50)
) 
go
CREATE PRIMARY KEY topics (id) 
go

CREATE TABLE customers (
    id integer UNIQUE INDEX DEFAULT _rowid,
    name char,
    balance integer default 0,
    address_street char,
    address_city char,
    address_country char,
    gps_location char
) 
go
CREATE PRIMARY KEY customers (id) 
go

CREATE TABLE orders (
    id integer UNIQUE INDEX DEFAULT _rowid,
    name char,
    billing_customer_id integer,
    shipping_customer_id integer
) 
go
CREATE PRIMARY KEY orders (id) 
go

CREATE TABLE movies (
    movieid integer UNIQUE INDEX DEFAULT _rowid,
    name text
) 
go
CREATE PRIMARY KEY movies (movieid) 
go

CREATE TABLE subscribers (
    nick CHAR(100) NOT NULL DEFAULT _rowid,
    name CHAR(100)
) 
go
CREATE PRIMARY KEY subscribers (nick) 
go

CREATE TABLE booleantests (
    id integer UNIQUE INDEX DEFAULT _rowid,
    value boolean
) 
go
CREATE PRIMARY KEY booleantests (id) 
go

CREATE TABLE defaults (
    id integer UNIQUE INDEX ,
    modified_date date default CURDATE(),
    modified_date_function date default NOW(),
    fixed_date date default '2004-01-01',
    modified_time timestamp default NOW(),
    modified_time_function timestamp default NOW(),
    fixed_time timestamp default '2004-01-01 00:00:00.000000-00',
    char1 char(1) default 'Y',
    char2 char(50) default 'a char field',
    char3 text default 'a text field'
) 
go

CREATE TABLE auto_id_tests (
    auto_id integer UNIQUE INDEX DEFAULT _rowid,
    value integer
) 
go
CREATE PRIMARY KEY auto_id_tests (auto_id) 
go

CREATE TABLE entrants (
  id integer UNIQUE INDEX ,
  name text,
  course_id integer
) 
go

CREATE TABLE colnametests (
  id integer UNIQUE INDEX ,
  references integer NOT NULL
) 
go

CREATE TABLE mixins (
  id integer UNIQUE INDEX DEFAULT _rowid,
  parent_id integer,
  type char,  
  pos integer,
  lft integer,
  rgt integer,
  root_id integer,  
  created_at timestamp,
  updated_at timestamp
) 
go
CREATE PRIMARY KEY mixins (id) 
go

CREATE TABLE people (
  id integer UNIQUE INDEX DEFAULT _rowid,
  first_name text,
  lock_version integer default 0
) 
go
CREATE PRIMARY KEY people (id) 
go

CREATE TABLE readers (
    id integer UNIQUE INDEX DEFAULT _rowid,
    post_id integer NOT NULL,
    person_id integer NOT NULL
)
go
CREATE PRIMARY KEY readers (id)
go

CREATE TABLE binaries ( 
  id integer UNIQUE INDEX DEFAULT _rowid,
  data object
) 
go
CREATE PRIMARY KEY binaries (id) 
go

CREATE TABLE computers (
  id integer UNIQUE INDEX ,
  developer integer NOT NULL,
  extendedWarranty integer NOT NULL
) 
go

CREATE TABLE posts (
  id integer UNIQUE INDEX ,
  author_id integer,
  title char(255),
  type char(255),
  body text
) 
go

CREATE TABLE comments (
  id integer UNIQUE INDEX ,
  post_id integer,
  type char(255),
  body text
) 
go

CREATE TABLE authors (
  id integer UNIQUE INDEX ,
  name char(255) default NULL
) 
go

CREATE TABLE tasks (
  id integer UNIQUE INDEX DEFAULT _rowid,
  starting datetime,
  ending datetime
) 
go
CREATE PRIMARY KEY tasks (id) 
go

CREATE TABLE categories (
  id integer UNIQUE INDEX ,
  name char(255),
  type char(255)
) 
go

CREATE TABLE categories_posts (
  category_id integer NOT NULL,
  post_id integer NOT NULL
) 
go

CREATE TABLE fk_test_has_pk (
  id INTEGER NOT NULL DEFAULT _rowid
) 
go
CREATE PRIMARY KEY fk_test_has_pk (id) 
go

CREATE TABLE fk_test_has_fk (
  id    INTEGER NOT NULL DEFAULT _rowid,
  fk_id INTEGER NOT NULL REFERENCES fk_test_has_pk.id
) 
go
CREATE PRIMARY KEY fk_test_has_fk (id) 
go

CREATE TABLE keyboards (
  key_number integer UNIQUE INDEX DEFAULT _rowid,
  name char(50)
) 
go
CREATE PRIMARY KEY keyboards (key_number) 
go

CREATE TABLE legacy_things (
  id INTEGER NOT NULL DEFAULT _rowid,
  tps_report_number INTEGER default NULL,
  version integer NOT NULL default 0
)
go
CREATE PRIMARY KEY legacy_things (id)
go

CREATE TABLE numeric_data (
  id INTEGER NOT NULL DEFAULT _rowid,
  bank_balance DECIMAL(10,2),
  big_bank_balance DECIMAL(15,2),
  world_population DECIMAL(10),
  my_house_population DECIMAL(2),
  decimal_number_with_default DECIMAL(3,2) DEFAULT 2.78
);
go
CREATE PRIMARY KEY numeric_data (id)
go

CREATE TABLE mixed_case_monkeys (
  monkeyID INTEGER NOT NULL DEFAULT _rowid,
  fleaCount INTEGER
);
go
CREATE PRIMARY KEY mixed_case_monkeys (monkeyID)
go
