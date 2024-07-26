SET search_path = public, pg_catalog;

CREATE TABLE accounts (
    id serial NOT NULL,
    firm_id integer,
    credit_limit integer
);
SELECT setval('accounts_id_seq', 100);

CREATE TABLE companies (
    id serial NOT NULL,
    "type" character varying(50),
    firm_id integer,
    name character varying(50),
    client_of integer,
    companies_count integer DEFAULT 0,
    rating integer default 1
);
SELECT setval('companies_id_seq', 100);

CREATE TABLE developers_projects (
    developer_id integer NOT NULL,
    project_id integer NOT NULL
);

CREATE TABLE developers (
    id serial NOT NULL,
    name character varying(100)
);
SELECT setval('developers_id_seq', 100);

CREATE TABLE projects (
    id serial NOT NULL,
    name character varying(100)
);
SELECT setval('projects_id_seq', 100);

CREATE TABLE topics (
    id serial NOT NULL,
    title character varying(255),
    author_name character varying(255),
    author_email_address character varying(255),
    written_on timestamp without time zone,
    last_read date,
    content text,
    reply_count integer,
    parent_id integer,
    "type" character varying(50),
    approved smallint DEFAULT 1
);
SELECT setval('topics_id_seq', 100);

CREATE TABLE customers (
    id serial NOT NULL,
    name character varying,
    balance integer default 0,
    address_street character varying,
    address_city character varying,
    address_country character varying
);
SELECT setval('customers_id_seq', 100);

CREATE TABLE movies (
    movieid serial NOT NULL,
    name text
);

CREATE TABLE subscribers (
    nick text NOT NULL,
    name text
);

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);

ALTER TABLE ONLY companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);

ALTER TABLE ONLY developers
    ADD CONSTRAINT developers_pkey PRIMARY KEY (id);

ALTER TABLE ONLY customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);

ALTER TABLE ONLY movies
    ADD CONSTRAINT movies_pkey PRIMARY KEY (movieid);

ALTER TABLE ONLY subscribers
    ADD CONSTRAINT subscribers_pkey PRIMARY KEY (nick);

