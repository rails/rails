CREATE TABLE accounts (
  id int NOT NULL IDENTITY(1, 1),
  firm_id int default NULL,
  credit_limit int default NULL,
  PRIMARY KEY  (id)
)

CREATE TABLE companies (
  id int NOT NULL IDENTITY(1, 1),
  type varchar(50) default NULL,
  ruby_type varchar(50) default NULL,
  firm_id int default NULL,
  name varchar(50) default NULL,
  client_of int default NULL,
  companies_count int default 0,
  rating int default 1,
  PRIMARY KEY  (id)
)

CREATE TABLE topics (
  id int NOT NULL IDENTITY(1, 1),
  title varchar(255) default NULL,
  author_name varchar(255) default NULL,
  author_email_address varchar(255) default NULL,
  written_on datetime default NULL,
  last_read datetime default NULL,
  content text,
  approved tinyint default 1,
  replies_count int default 0,
  parent_id int default NULL,
  type varchar(50) default NULL,
  PRIMARY KEY  (id)
)

CREATE TABLE developers (
  id int NOT NULL IDENTITY(1, 1),
  name varchar(100) default NULL,
  PRIMARY KEY  (id)
);

CREATE TABLE projects (
  id int NOT NULL IDENTITY(1, 1),
  name varchar(100) default NULL,
  salary int default NULL,
  PRIMARY KEY  (id)
);

CREATE TABLE developers_projects (
  developer_id int NOT NULL,
  project_id int NOT NULL
);

CREATE TABLE customers (
  id int NOT NULL IDENTITY(1, 1),
  name varchar(100) default NULL,
  balance int default 0,
  address_street varchar(100) default NULL,
  address_city varchar(100) default NULL,
  address_country varchar(100) default NULL,
  PRIMARY KEY  (id)
);

CREATE TABLE movies (
  movieid int NOT NULL IDENTITY(1, 1),
  name varchar(100) default NULL,
   PRIMARY KEY  (movieid)
);

CREATE TABLE subscribers (
  nick varchar(100) NOT NULL,
  name varchar(100) default NULL,
  PRIMARY KEY  (nick)
);

CREATE TABLE booleantests (
  id int NOT NULL IDENTITY(1, 1),
  value integer default NULL,
  PRIMARY KEY (id)
);

CREATE TABLE auto_id_tests (
  auto_id int NOT NULL IDENTITY(1, 1),
  value int default NULL,
  PRIMARY KEY (auto_id)
);

CREATE TABLE entrants (
  id int NOT NULL PRIMARY KEY,
  name varchar(255) NOT NULL,
  course_id int NOT NULL
);

CREATE TABLE colnametests (
  id int NOT NULL IDENTITY(1, 1),
  [references] int NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE mixins (
  id int NOT NULL IDENTITY(1, 1),
  parent_id int default NULL,
  pos int default NULL,
  lft int default NULL,
  rgt int default NULL,
  root_id int default NULL,      
  created_at datetime default NULL,
  updated_at datetime default NULL,
  PRIMARY KEY (id)    
);


