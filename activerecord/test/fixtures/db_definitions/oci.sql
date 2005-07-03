create sequence rails_sequence minvalue 10000;

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

create table accounts (
    id integer not null,
    firm_id integer default null references companies initially deferred disable,
    credit_limit integer default null,
    primary key (id)
);

create table topics (
    id integer not null,
    title varchar(255) default null,
    author_name varchar(255) default null,
    author_email_address varchar(255) default null,
    written_on timestamp default null,
    bonus_time timestamp default null,
    last_read timestamp default null,
    content varchar(4000),
    approved integer default 1,
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
    approved integer default 1,
    replies_count integer default 0,
    parent_id integer references topics initially deferred disable,
    type varchar(50) default null,
    primary key (id)
);

create table developers (
    id integer not null,
    name varchar(100) default null,
    salary integer default 70000,
    created_at timestamp default null,
    updated_at timestamp default null,
    primary key (id)
);

create table projects (
    id integer not null,
    name varchar(100) default null,
    type varchar(255) default null,
    primary key (id)
);

create table developers_projects (
    developer_id integer not null references developers initially deferred disable,
    project_id integer not null references projects initially deferred disable,
    joined_on timestamp default null
);
-- Try again for 8i
create table developers_projects (
    developer_id integer not null references developers initially deferred disable,
    project_id integer not null references projects initially deferred disable,
    joined_on date default null
);

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

create table movies (
    movieid integer not null,
    name varchar(100) default null,
    primary key (movieid)
);

create table subscribers (
    nick varchar(100) not null,
    name varchar(100) default null,
    primary key (nick)
);

create table booleantests (
    id integer not null,
    value integer default null,
    primary key (id)
);

create table auto_id_tests (
    auto_id integer not null,
    value integer default null,
    primary key (auto_id)
);

create table entrants (
    id integer not null primary key,
    name varchar(255) not null,
    course_id integer not null
);

create table colnametests (
    id integer not null,
    references integer not null,
    primary key (id)
);

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

create table people (
    id integer not null,
    first_name varchar(40) null,
    lock_version integer default 0,
    primary key (id)
);

create table binaries (
    id integer not null,
    data blob null,
    primary key (id)
);

create table computers (
  id integer not null primary key,
  developer integer not null references developers initially deferred disable,
  extendedWarranty integer not null
);

create table posts (
  id integer not null primary key,
  author_id integer default null,
  title varchar(255) default null,
  type varchar(255) default null,
  body varchar(3000) default null
);

create table comments (
  id integer not null primary key,
  post_id integer default null,
  type varchar(255) default null,
  body varchar(3000) default null
);

create table authors (
  id integer not null primary key,
  name varchar(255) default null
);

create table tasks (
  id integer not null primary key,
  starting date default null,
  ending date default null
);

create table categories (
  id integer not null primary key,
  name varchar(255) default null,
  type varchar(255) default null
);

create table categories_posts (
  category_id integer not null references categories initially deferred disable,
  post_id integer not null references posts initially deferred disable
);

create table fk_test_has_pk (
  id integer not null primary key
);

create table fk_test_has_fk (
  id integer not null primary key,
  fk_id integer not null references fk_test_has_fk initially deferred disable
);
