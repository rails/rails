CREATE TABLE accounts (
    id integer DEFAULT unique,
    firm_id integer,
    credit_limit integer,
    PRIMARY KEY (id)
);
SET UNIQUE FOR accounts(id);

CREATE TABLE funny_jokes (
  id integer DEFAULT unique,
  firm_id integer default NULL,
  name character varying(50),
  PRIMARY KEY (id)
);
SET UNIQUE FOR funny_jokes(id);
  
CREATE TABLE companies (
  id integer DEFAULT unique,
    "type" character varying(50),
    "ruby_type" character varying(50),
    firm_id integer,
    name character varying(50),
    client_of integer,
    rating integer default 1,
    PRIMARY KEY (id)
);
SET UNIQUE FOR companies(id);

CREATE TABLE topics (
  id integer DEFAULT unique,
    title character varying(255),
    author_name character varying(255),
    author_email_address character varying(255),
    written_on timestamp,
    bonus_time time,
    last_read date,
    content varchar(65536),
    approved boolean default true,
    replies_count integer default 0,
    parent_id integer,
    "type" character varying(50),
    PRIMARY KEY (id)
);
SET UNIQUE FOR topics(id);

CREATE TABLE developers (
  id integer DEFAULT unique,
    name character varying(100),
    salary integer DEFAULT 70000,
    created_at timestamp,
    updated_at timestamp,
    PRIMARY KEY (id)
);
SET UNIQUE FOR developers(id);

CREATE TABLE projects (
  id integer DEFAULT unique,
    name character varying(100),
    type varchar(255),
    PRIMARY KEY (id)
);
SET UNIQUE FOR projects(id);

CREATE TABLE developers_projects (
    developer_id integer NOT NULL,
    project_id integer NOT NULL,
    joined_on date,
    access_level integer default 1
);

CREATE TABLE orders (
  id integer DEFAULT unique,
    name character varying(100),
    billing_customer_id integer,
    shipping_customer_id integer,
    PRIMARY KEY (id)
);
SET UNIQUE FOR orders(id);

CREATE TABLE customers (
  id integer DEFAULT unique,
    name character varying(100),
    balance integer default 0,
    address_street character varying(100),
    address_city character varying(100),
    address_country character varying(100),
    gps_location character varying(100),
    PRIMARY KEY (id)
);
SET UNIQUE FOR customers(id);

CREATE TABLE movies (
    movieid integer DEFAULT unique,
    name varchar(65536),
    PRIMARY KEY (movieid)
);
SET UNIQUE FOR movies(movieid);

CREATE TABLE subscribers (
    nick varchar(65536) NOT NULL,
    name varchar(65536),
    PRIMARY KEY (nick)
);

CREATE TABLE booleantests (
  id integer DEFAULT unique,
    value boolean,
    PRIMARY KEY (id)
);
SET UNIQUE FOR booleantests(id);

CREATE TABLE auto_id_tests (
  auto_id integer DEFAULT unique,
    value integer,
    PRIMARY KEY (auto_id)
);
SET UNIQUE FOR auto_id_tests(auto_id);

CREATE TABLE entrants (
  id integer DEFAULT unique,
  name varchar(65536),
  course_id integer,
  PRIMARY KEY (id)
);
SET UNIQUE FOR entrants(id);

CREATE TABLE colnametests (
  id integer DEFAULT unique,
  "references" integer NOT NULL,
  PRIMARY KEY (id)
);
SET UNIQUE FOR colnametests(id);

CREATE TABLE mixins (
  id integer DEFAULT unique,
  parent_id integer,
  type character varying(100),  
  pos integer,
  lft integer,
  rgt integer,
  root_id integer,  
  created_at timestamp,
  updated_at timestamp,
  PRIMARY KEY (id)
);
SET UNIQUE FOR mixins(id);

CREATE TABLE people (
  id integer DEFAULT unique,
  first_name varchar(65536),
  lock_version integer default 0,
  PRIMARY KEY  (id)
);
SET UNIQUE FOR people(id);

CREATE TABLE readers (
  id integer DEFAULT unique,
  post_id INTEGER NOT NULL,
  person_id INTEGER NOT NULL,
  PRIMARY KEY  (id)
);
SET UNIQUE FOR readers(id);

CREATE TABLE binaries ( 
  id integer DEFAULT unique,
  data BLOB,
  PRIMARY KEY (id)
);
SET UNIQUE FOR binaries(id);

CREATE TABLE computers (
  id integer DEFAULT unique,
  developer integer NOT NULL,
  "extendedWarranty" integer NOT NULL,
  PRIMARY KEY (id)
);
SET UNIQUE FOR computers(id);

CREATE TABLE posts (
  id integer DEFAULT unique,
  author_id integer,
  title varchar(255),
  type varchar(255),
  body varchar(65536),
  PRIMARY KEY (id)
);
SET UNIQUE FOR posts(id);

CREATE TABLE comments (
  id integer DEFAULT unique,
  post_id integer,
  type varchar(255),
  body varchar(65536),
  PRIMARY KEY (id)
);
SET UNIQUE FOR comments(id);

CREATE TABLE authors (
  id integer DEFAULT unique,
  name varchar(255) default NULL,
  PRIMARY KEY (id)
);
SET UNIQUE FOR authors(id);

CREATE TABLE tasks (
  id integer DEFAULT unique,
  starting timestamp,
  ending timestamp,
  PRIMARY KEY (id)
);
SET UNIQUE FOR tasks(id);

CREATE TABLE categories (
  id integer DEFAULT unique,
  name varchar(255),
  type varchar(255),
  PRIMARY KEY (id)
);
SET UNIQUE FOR categories(id);

CREATE TABLE categories_posts (
  category_id integer NOT NULL,
  post_id integer NOT NULL
);

CREATE TABLE fk_test_has_pk (
  id INTEGER NOT NULL PRIMARY KEY
);
SET UNIQUE FOR fk_test_has_pk(id);

CREATE TABLE fk_test_has_fk (
  id    INTEGER NOT NULL PRIMARY KEY,
  fk_id INTEGER NOT NULL REFERENCES fk_test_has_fk(id)
);
SET UNIQUE FOR fk_test_has_fk(id);

CREATE TABLE keyboards (
  key_number integer DEFAULT unique,
  "name" character varying(50),
  PRIMARY KEY (key_number)
);
SET UNIQUE FOR keyboards(key_number);

create table "legacy_things"
(
  "id" int,
  "tps_report_number" int default NULL,
  "version" int default 0 not null,
  primary key ("id")
);
SET UNIQUE FOR legacy_things(id);

CREATE TABLE "numeric_data" (
  "id" integer NOT NULL
  "bank_balance" DECIMAL(10,2),
  "big_bank_balance" DECIMAL(15,2),
  "world_population" DECIMAL(10),
  "my_house_population" DECIMAL(2),
  "decimal_number_with_default" DECIMAL(3,2) DEFAULT 2.78,
  primary key ("id")
);
SET UNIQUE FOR numeric_data(id);
