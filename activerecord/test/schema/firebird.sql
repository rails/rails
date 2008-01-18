CREATE DOMAIN D_BOOLEAN AS SMALLINT CHECK (VALUE IN (0, 1) OR VALUE IS NULL);

CREATE TABLE accounts (
  id BIGINT NOT NULL,
  firm_id BIGINT,
  credit_limit INTEGER,
  PRIMARY KEY (id)
);
CREATE GENERATOR accounts_seq;
SET GENERATOR accounts_seq TO 10000;

CREATE TABLE funny_jokes (
  id BIGINT NOT NULL,
  name VARCHAR(50),
  PRIMARY KEY (id)
);
CREATE GENERATOR funny_jokes_seq;
SET GENERATOR funny_jokes_seq TO 10000;

CREATE TABLE companies (
  id BIGINT NOT NULL,
  "TYPE" VARCHAR(50),
  ruby_type VARCHAR(50),
  firm_id BIGINT,
  name VARCHAR(50),
  client_of INTEGER,
  rating INTEGER DEFAULT 1,
  PRIMARY KEY (id)
);
CREATE GENERATOR companies_nonstd_seq;
SET GENERATOR companies_nonstd_seq TO 10000;

CREATE TABLE topics (
  id BIGINT NOT NULL,
  title VARCHAR(255),
  author_name VARCHAR(255),
  author_email_address VARCHAR(255),
  written_on TIMESTAMP,
  bonus_time TIME,
  last_read DATE,
  content VARCHAR(4000),
  approved D_BOOLEAN DEFAULT 1,
  replies_count INTEGER DEFAULT 0,
  parent_id BIGINT,
  "TYPE" VARCHAR(50),
  PRIMARY KEY (id)
);
CREATE GENERATOR topics_seq;
SET GENERATOR topics_seq TO 10000;

CREATE TABLE developers (
  id BIGINT NOT NULL,
  name VARCHAR(100),
  salary INTEGER DEFAULT 70000,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  PRIMARY KEY (id)
);
CREATE GENERATOR developers_seq;
SET GENERATOR developers_seq TO 10000;

CREATE TABLE projects (
  id BIGINT NOT NULL,
  name VARCHAR(100),
  "TYPE" VARCHAR(255),
  PRIMARY KEY (id)
);
CREATE GENERATOR projects_seq;
SET GENERATOR projects_seq TO 10000;

CREATE TABLE developers_projects (
  developer_id BIGINT NOT NULL,
  project_id BIGINT NOT NULL,
  joined_on DATE,
  access_level SMALLINT DEFAULT 1
);

CREATE TABLE orders (
  id BIGINT NOT NULL,
  name VARCHAR(100),
  billing_customer_id BIGINT,
  shipping_customer_id BIGINT,
  PRIMARY KEY (id)
);
CREATE GENERATOR orders_seq;
SET GENERATOR orders_seq TO 10000;

CREATE TABLE customers (
  id BIGINT NOT NULL,
  name VARCHAR(100),
  balance INTEGER DEFAULT 0,
  address_street VARCHAR(100),
  address_city VARCHAR(100),
  address_country VARCHAR(100),
  gps_location VARCHAR(100),
  PRIMARY KEY (id)
);
CREATE GENERATOR customers_seq;
SET GENERATOR customers_seq TO 10000;

CREATE TABLE movies (
  movieid BIGINT NOT NULL,
  name varchar(100),
  PRIMARY KEY (movieid)
);
CREATE GENERATOR movies_seq;
SET GENERATOR movies_seq TO 10000;

CREATE TABLE subscribers (
  nick VARCHAR(100) NOT NULL,
  name VARCHAR(100),
  PRIMARY KEY (nick)
);

CREATE TABLE booleantests (
  id BIGINT NOT NULL,
  "VALUE" D_BOOLEAN,
  PRIMARY KEY (id)
);
CREATE GENERATOR booleantests_seq;
SET GENERATOR booleantests_seq TO 10000;

CREATE TABLE auto_id_tests (
  auto_id BIGINT NOT NULL,
  "VALUE" INTEGER,
  PRIMARY KEY (auto_id)
);
CREATE GENERATOR auto_id_tests_seq;
SET GENERATOR auto_id_tests_seq TO 10000;

CREATE TABLE entrants (
  id BIGINT NOT NULL,
  name VARCHAR(255) NOT NULL,
  course_id INTEGER NOT NULL,
  PRIMARY KEY (id)
);
CREATE GENERATOR entrants_seq;
SET GENERATOR entrants_seq TO 10000;

CREATE TABLE colnametests (
  id BIGINT NOT NULL,
  "REFERENCES" INTEGER NOT NULL,
  PRIMARY KEY (id)
);
CREATE GENERATOR colnametests_seq;
SET GENERATOR colnametests_seq TO 10000;

CREATE TABLE mixins (
  id BIGINT NOT NULL,
  parent_id BIGINT,
  pos INTEGER,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  lft INTEGER,
  rgt INTEGER,
  root_id BIGINT,
  "TYPE" VARCHAR(40),
  PRIMARY KEY (id)
);
CREATE GENERATOR mixins_seq;
SET GENERATOR mixins_seq TO 10000;

CREATE TABLE people (
  id BIGINT NOT NULL,
  first_name VARCHAR(40),
  lock_version INTEGER DEFAULT 0 NOT NULL,
  PRIMARY KEY (id)
);
CREATE GENERATOR people_seq;
SET GENERATOR people_seq TO 10000;

CREATE TABLE readers (
    id BIGINT NOT NULL,
    post_id BIGINT NOT NULL,
    person_id BIGINT NOT NULL,
    PRIMARY KEY (id)
);
CREATE GENERATOR readers_seq;
SET GENERATOR readers_seq TO 10000;

CREATE TABLE binaries (
  id BIGINT NOT NULL,
  data BLOB,
  PRIMARY KEY (id)
);
CREATE GENERATOR binaries_seq;
SET GENERATOR binaries_seq TO 10000;

CREATE TABLE computers (
  id BIGINT NOT NULL,
  developer INTEGER NOT NULL,
  "extendedWarranty" INTEGER NOT NULL,
  PRIMARY KEY (id)
);
CREATE GENERATOR computers_seq;
SET GENERATOR computers_seq TO 10000;

CREATE TABLE posts (
  id BIGINT NOT NULL,
  author_id BIGINT,
  title VARCHAR(255) NOT NULL,
  "TYPE" VARCHAR(255) NOT NULL,
  body VARCHAR(3000) NOT NULL,
  PRIMARY KEY (id)
);
CREATE GENERATOR posts_seq;
SET GENERATOR posts_seq TO 10000;

CREATE TABLE comments (
  id BIGINT NOT NULL,
  post_id BIGINT NOT NULL,
  "TYPE" VARCHAR(255) NOT NULL,
  body VARCHAR(3000) NOT NULL,
  PRIMARY KEY (id)
);
CREATE GENERATOR comments_seq;
SET GENERATOR comments_seq TO 10000;

CREATE TABLE authors (
  id BIGINT NOT NULL,
  name VARCHAR(255) NOT NULL,
  PRIMARY KEY (id)
);
CREATE GENERATOR authors_seq;
SET GENERATOR authors_seq TO 10000;

CREATE TABLE tasks (
  id BIGINT NOT NULL,
  "STARTING" TIMESTAMP,
  ending TIMESTAMP,
  PRIMARY KEY (id)
);
CREATE GENERATOR tasks_seq;
SET GENERATOR tasks_seq TO 10000;

CREATE TABLE categories (
  id BIGINT NOT NULL,
  name VARCHAR(255) NOT NULL,
  "TYPE" VARCHAR(255) NOT NULL,
  PRIMARY KEY (id)
);
CREATE GENERATOR categories_seq;
SET GENERATOR categories_seq TO 10000;

CREATE TABLE categories_posts (
  category_id BIGINT NOT NULL,
  post_id BIGINT NOT NULL,
  PRIMARY KEY (category_id, post_id)
);

CREATE TABLE fk_test_has_pk (
  id BIGINT NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE fk_test_has_fk (
  id BIGINT NOT NULL,
  fk_id BIGINT NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (fk_id) REFERENCES fk_test_has_pk(id)
);

CREATE TABLE keyboards (
  key_number BIGINT NOT NULL,
  name VARCHAR(50),
  PRIMARY KEY (key_number)
);
CREATE GENERATOR keyboards_seq;
SET GENERATOR keyboards_seq TO 10000;

CREATE TABLE defaults (
  id BIGINT NOT NULL,
  default_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE GENERATOR defaults_seq;
SET GENERATOR defaults_seq TO 10000;

CREATE TABLE legacy_things (
  id BIGINT NOT NULL,
  tps_report_number INTEGER,
  version INTEGER DEFAULT 0 NOT NULL,
  PRIMARY KEY (id)
);
CREATE GENERATOR legacy_things_seq;
SET GENERATOR legacy_things_seq TO 10000;

CREATE TABLE numeric_data (
  id BIGINT NOT NULL,
  bank_balance DECIMAL(10,2),
  big_bank_balance DECIMAL(15,2),
  world_population DECIMAL(10),
  my_house_population DECIMAL(2),
  decimal_number_with_default DECIMAL(3,2) DEFAULT 2.78,
  PRIMARY KEY (id)
);
CREATE GENERATOR numeric_data_seq;
SET GENERATOR numeric_data_seq TO 10000;

CREATE TABLE mixed_case_monkeys (
 "monkeyID" BIGINT NOT NULL,
 "fleaCount" INTEGER
);
CREATE GENERATOR mixed_case_monkeys_seq;
SET GENERATOR mixed_case_monkeys_seq TO 10000;

CREATE TABLE minimalistics (
  id BIGINT NOT NULL
);
CREATE GENERATOR minimalistics_seq;
SET GENERATOR minimalistics_seq TO 10000;
