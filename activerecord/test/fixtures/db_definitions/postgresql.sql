CREATE SEQUENCE public.accounts_id_seq START 100;

CREATE TABLE accounts (
    id integer primary key DEFAULT nextval('public.accounts_id_seq'),
    firm_id integer,
    credit_limit integer
);

CREATE TABLE funny_jokes (
  id serial,
  name character varying(50)
);

CREATE SEQUENCE companies_nonstd_seq START 101;

CREATE TABLE companies (
    id integer primary key DEFAULT nextval('companies_nonstd_seq'),
    "type" character varying(50),
    "ruby_type" character varying(50),
    firm_id integer,
    name character varying(50),
    client_of integer,
    rating integer default 1
);

CREATE TABLE developers_projects (
    developer_id integer NOT NULL,
    project_id integer NOT NULL,
    joined_on date,
    access_level integer default 1
);

CREATE TABLE developers (
    id serial primary key,
    name character varying(100),
    salary integer DEFAULT 70000,
    created_at timestamp,
    updated_at timestamp
);
SELECT setval('developers_id_seq', 100);

CREATE TABLE projects (
    id serial primary key,
    name character varying(100),
    type varchar(255)
);
SELECT setval('projects_id_seq', 100);

CREATE TABLE topics (
    id serial primary key,
    title character varying(255),
    author_name character varying(255),
    author_email_address character varying(255),
    written_on timestamp without time zone,
    bonus_time time,
    last_read date,
    content text,
    approved boolean default true,
    replies_count integer default 0,
    parent_id integer,
    "type" character varying(50)
);
SELECT setval('topics_id_seq', 100);

CREATE TABLE customers (
    id serial primary key,
    name character varying,
    balance integer default 0,
    address_street character varying,
    address_city character varying,
    address_country character varying,
    gps_location character varying
);
SELECT setval('customers_id_seq', 100);

CREATE TABLE orders (
    id serial primary key,
    name character varying,
    billing_customer_id integer,
    shipping_customer_id integer
);
SELECT setval('orders_id_seq', 100);

CREATE TABLE movies (
    movieid serial primary key,
    name text
);

CREATE TABLE subscribers (
    nick text primary key NOT NULL,
    name text
);

CREATE TABLE booleantests (
    id serial primary key,
    value boolean
);

CREATE TABLE defaults (
    id serial primary key,
    modified_date date default CURRENT_DATE,
    modified_date_function date default now(),
    fixed_date date default '2004-01-01',
    modified_time timestamp default CURRENT_TIMESTAMP,
    modified_time_function timestamp default now(),
    fixed_time timestamp default '2004-01-01 00:00:00.000000-00',
    char1 char(1) default 'Y',
    char2 character varying(50) default 'a varchar field',
    char3 text default 'a text field',
    positive_integer integer default 1,
    negative_integer integer default -1,
    decimal_number decimal(3,2) default 2.78
);

CREATE TABLE auto_id_tests (
    auto_id serial primary key,
    value integer
);

CREATE TABLE entrants (
  id serial primary key,
  name text not null,
  course_id integer not null
);

CREATE TABLE colnametests (
  id serial primary key,
  "references" integer NOT NULL
);

CREATE TABLE mixins (
  id serial primary key,
  parent_id integer,
  type character varying,  
  pos integer,
  lft integer,
  rgt integer,
  root_id integer,  
  created_at timestamp,
  updated_at timestamp
);

CREATE TABLE people (
  id serial primary key,
  first_name text,
  lock_version integer default 0
);

CREATE TABLE readers (
    id serial primary key,
    post_id integer NOT NULL,
    person_id integer NOT NULL
);

CREATE TABLE binaries (
  id serial primary key,
  data bytea
);

CREATE TABLE computers (
  id serial primary key,
  developer integer NOT NULL,
  "extendedWarranty" integer NOT NULL
);

CREATE TABLE posts (
  id serial primary key,
  author_id integer,
  title varchar(255),
  type varchar(255),
  body text
);

CREATE TABLE comments (
  id serial primary key,
  post_id integer,
  type varchar(255),
  body text
);

CREATE TABLE authors (
  id serial primary key,
  name varchar(255) default NULL
);

CREATE TABLE tasks (
  id serial primary key,
  starting timestamp,
  ending timestamp
);

CREATE TABLE categories (
  id serial primary key,
  name varchar(255),
  type varchar(255)
);

CREATE TABLE categories_posts (
  category_id integer NOT NULL,
  post_id integer NOT NULL
);

CREATE TABLE fk_test_has_pk (
  id INTEGER NOT NULL PRIMARY KEY
);

CREATE TABLE fk_test_has_fk (
  id    INTEGER NOT NULL PRIMARY KEY,
  fk_id INTEGER NOT NULL REFERENCES fk_test_has_fk(id)
);

CREATE TABLE geometrics (
  id serial primary key,
  a_point point,
  -- a_line line, (the line type is currently not implemented in postgresql)
  a_line_segment lseg,
  a_box box,
  a_path path,
  a_polygon polygon,
  a_circle circle
);

CREATE TABLE keyboards (
  key_number serial primary key,
  "name" character varying(50)
);

--Altered lock_version column name.
CREATE TABLE legacy_things (
  id serial primary key,
  tps_report_number integer,
  version integer default 0
);

CREATE TABLE numeric_data (
  id serial primary key,
  bank_balance decimal(10,2),
  big_bank_balance decimal(15,2),
  world_population decimal(10),
  my_house_population decimal(2),
  decimal_number_with_default decimal(3,2) default 2.78
);

CREATE TABLE mixed_case_monkeys (
 "monkeyID" INTEGER PRIMARY KEY,
 "fleaCount" INTEGER
);
