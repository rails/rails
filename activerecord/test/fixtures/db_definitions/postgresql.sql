SET search_path = public, pg_catalog;

CREATE TABLE accounts (
    id serial,
    firm_id integer,
    credit_limit integer,
    PRIMARY KEY (id)
);
SELECT setval('accounts_id_seq', 100);

CREATE TABLE companies (
    id serial,
    "type" character varying(50),
    firm_id integer,
    name character varying(50),
    client_of integer,
    companies_count integer DEFAULT 0,
    rating integer default 1,
    PRIMARY KEY (id)
);
SELECT setval('companies_id_seq', 100);

CREATE TABLE developers_projects (
    developer_id integer NOT NULL,
    project_id integer NOT NULL
);

CREATE TABLE developers (
    id serial,
    name character varying(100),
    PRIMARY KEY (id)
);
SELECT setval('developers_id_seq', 100);

CREATE TABLE projects (
    id serial,
    name character varying(100),
    PRIMARY KEY (id)
);
SELECT setval('projects_id_seq', 100);

CREATE TABLE topics (
    id serial,
    title character varying(255),
    author_name character varying(255),
    author_email_address character varying(255),
    written_on timestamp without time zone,
    last_read date,
    content text,
    reply_count integer,
    parent_id integer,
    "type" character varying(50),
    approved smallint DEFAULT 1,
    PRIMARY KEY (id)
);
SELECT setval('topics_id_seq', 100);

CREATE TABLE customers (
    id serial,
    name character varying,
    balance integer default 0,
    address_street character varying,
    address_city character varying,
    address_country character varying,
    PRIMARY KEY (id)
);
SELECT setval('customers_id_seq', 100);

CREATE TABLE movies (
    movieid serial,
    name text,
    PRIMARY KEY (movieid)
);

CREATE TABLE subscribers (
    nick text NOT NULL,
    name text,
    PRIMARY KEY (nick)
);

CREATE TABLE booleantests (
    id serial,
    value boolean,
    PRIMARY KEY (id)
);

