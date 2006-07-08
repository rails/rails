create table companies (
    id integer not null,
    type varchar(50) default null,
    ruby_type varchar(50) default null,
    firm_id integer default null references companies initially deferred disable,
    name varchar(50) default null,
    client_of integer default null references companies initially deferred disable,
    companies_count integer default 0,
    rating integer default 1,
    primary key (id)
);

-- non-standard sequence name used to test set_sequence_name
--
create sequence companies_nonstd_seq minvalue 10000;

create table funny_jokes (
  id integer not null,
  name varchar(50) default null,
  primary key (id)
);
create sequence funny_jokes_seq minvalue 10000;

create table accounts (
    id integer not null,
    firm_id integer default null references companies initially deferred disable,
    credit_limit integer default null
);
create sequence accounts_seq minvalue 10000;

create table topics (
    id integer not null,
    title varchar(255) default null,
    author_name varchar(255) default null,
    author_email_address varchar(255) default null,
    written_on timestamp default null,
    bonus_time timestamp default null,
    last_read timestamp default null,
    content varchar(4000),
    approved number(1) default 1,
    replies_count integer default 0,
    parent_id integer references topics initially deferred disable,
    type varchar(50) default null,
    primary key (id)
);
-- try again for 8i
create table topics (
    id integer not null,
    title varchar(255) default null,
    author_name varchar(255) default null,
    author_email_address varchar(255) default null,
    written_on date default null,
    bonus_time date default null,
    last_read date default null,
    content varchar(4000),
    approved number(1) default 1,
    replies_count integer default 0,
    parent_id integer references topics initially deferred disable,
    type varchar(50) default null,
    primary key (id)
);
create sequence topics_seq minvalue 10000;

create synonym subjects for topics;

create table developers (
    id integer not null,
    name varchar(100) default null,
    salary integer default 70000,
    created_at timestamp default null,
    updated_at timestamp default null,
    primary key (id)
);
create sequence developers_seq minvalue 10000;

create table projects (
    id integer not null,
    name varchar(100) default null,
    type varchar(255) default null,
    primary key (id)
);
create sequence projects_seq minvalue 10000;

create table developers_projects (
    developer_id integer not null references developers initially deferred disable,
    project_id integer not null references projects initially deferred disable,
    joined_on timestamp default null,
    access_level integer default 1
);
-- Try again for 8i
create table developers_projects (
    developer_id integer not null references developers initially deferred disable,
    project_id integer not null references projects initially deferred disable,
    joined_on date default null
);
create sequence developers_projects_seq minvalue 10000;

create table orders (
    id integer not null,
    name varchar(100) default null,
    billing_customer_id integer default null,
    shipping_customer_id integer default null,
    primary key (id)
);
create sequence orders_seq minvalue 10000;

create table customers (
    id integer not null,
    name varchar(100) default null,
    balance integer default 0,
    address_street varchar(100) default null,
    address_city varchar(100) default null,
    address_country varchar(100) default null,
    gps_location varchar(100) default null,
    primary key (id)
);
create sequence customers_seq minvalue 10000;

create table movies (
    movieid integer not null,
    name varchar(100) default null,
    primary key (movieid)
);
create sequence movies_seq minvalue 10000;

create table subscribers (
    nick varchar(100) not null,
    name varchar(100) default null,
    primary key (nick)
);
create sequence subscribers_seq minvalue 10000;

create table booleantests (
    id integer not null,
    value integer default null,
    primary key (id)
);
create sequence booleantests_seq minvalue 10000;

create table auto_id_tests (
    auto_id integer not null,
    value integer default null,
    primary key (auto_id)
);
create sequence auto_id_tests_seq minvalue 10000;

create table entrants (
    id integer not null primary key,
    name varchar(255) not null,
    course_id integer not null
);
create sequence entrants_seq minvalue 10000;

create table colnametests (
    id integer not null,
    references integer not null,
    primary key (id)
);
create sequence colnametests_seq minvalue 10000;

create table mixins (
    id integer not null,
    parent_id integer default null references mixins initially deferred disable,
    type varchar(40) default null,
    pos integer default null,
    lft integer default null,
    rgt integer default null,
    root_id integer default null,
    created_at timestamp default null,
    updated_at timestamp default null,
    primary key (id)
);
-- try again for 8i
create table mixins (
    id integer not null,
    parent_id integer default null references mixins initially deferred disable,
    type varchar(40) default null,
    pos integer default null,
    lft integer default null,
    rgt integer default null,
    root_id integer default null,
    created_at date default null,
    updated_at date default null,
    primary key (id)
);
create sequence mixins_seq minvalue 10000;

create table people (
    id integer not null,
    first_name varchar(40) null,
    lock_version integer default 0,
    primary key (id)
);
create sequence people_seq minvalue 10000;

create table readers (
    id integer not null,
    post_id integer not null,
    person_id integer not null,
    primary key (id)
);
create sequence readers_seq minvalue 10000;

create table binaries (
    id integer not null,
    data blob null,
    primary key (id)
);
create sequence binaries_seq minvalue 10000;

create table computers (
  id integer not null primary key,
  developer integer not null references developers initially deferred disable,
  "extendedWarranty" integer not null
);
create sequence computers_seq minvalue 10000;

create table posts (
  id integer not null primary key,
  author_id integer default null,
  title varchar(255) default null,
  type varchar(255) default null,
  body varchar(3000) default null
);
create sequence posts_seq minvalue 10000;

create table comments (
  id integer not null primary key,
  post_id integer default null,
  type varchar(255) default null,
  body varchar(3000) default null
);
create sequence comments_seq minvalue 10000;

create table authors (
  id integer not null primary key,
  name varchar(255) default null
);
create sequence authors_seq minvalue 10000;

create table tasks (
  id integer not null primary key,
  starting date default null,
  ending date default null
);
create sequence tasks_seq minvalue 10000;

create table categories (
  id integer not null primary key,
  name varchar(255) default null,
  type varchar(255) default null
);
create sequence categories_seq minvalue 10000;

create table categories_posts (
  category_id integer not null references categories initially deferred disable,
  post_id integer not null references posts initially deferred disable
);
create sequence categories_posts_seq minvalue 10000;

create table fk_test_has_pk (
  id integer not null primary key
);
create sequence fk_test_has_pk_seq minvalue 10000;

create table fk_test_has_fk (
  id integer not null primary key,
  fk_id integer not null references fk_test_has_fk initially deferred disable
);
create sequence fk_test_has_fk_seq minvalue 10000;

create table keyboards (
  key_number integer not null,
  name varchar(50) default null
);
create sequence keyboards_seq minvalue 10000;

create table test_oracle_defaults (
  id integer not null primary key,
  test_char char(1) default 'X' not null,
  test_string varchar2(20) default 'hello' not null,
  test_int integer default 3 not null
);
create sequence test_oracle_defaults_seq minvalue 10000;

--This table has an altered lock_version column name.
create table legacy_things (
    id integer not null primary key,
    tps_report_number integer default null,
    version integer default 0
);
create sequence legacy_things_seq minvalue 10000;

CREATE TABLE numeric_data (
  id integer NOT NULL PRIMARY KEY,
  bank_balance decimal(10,2),
  big_bank_balance decimal(15,2),
  world_population decimal(10),
  my_house_population decimal(2),
  decimal_number_with_default decimal(3,2) DEFAULT 2.78
);
create sequence numeric_data_seq minvalue 10000;
