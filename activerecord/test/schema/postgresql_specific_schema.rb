ActiveRecord::Schema.define do

  %w(postgresql_tsvectors postgresql_arrays postgresql_moneys postgresql_numbers postgresql_times postgresql_network_addresses postgresql_bit_strings
      postgresql_oids postgresql_xml_data_type defaults geometrics postgresql_timestamp_with_zones).each do |table_name|
    execute "DROP TABLE  IF EXISTS #{quote_table_name table_name}"
  end

  execute 'DROP SEQUENCE IF EXISTS companies_nonstd_seq CASCADE'
  execute 'CREATE SEQUENCE companies_nonstd_seq START 101 OWNED BY companies.id'
  execute "ALTER TABLE companies ALTER COLUMN id SET DEFAULT nextval('companies_nonstd_seq')"
  execute 'DROP SEQUENCE IF EXISTS companies_id_seq'

  execute "DROP SCHEMA IF EXISTS schema_1 CASCADE"

  %w(accounts_id_seq developers_id_seq projects_id_seq topics_id_seq customers_id_seq orders_id_seq).each do |seq_name|
    execute "SELECT setval('#{seq_name}', 100)"
  end

  execute <<_SQL
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
    decimal_number decimal(3,2) default 2.78,
    multiline_default text DEFAULT '--- []

'::text
);
_SQL

  execute "CREATE SCHEMA schema_1"
  execute "CREATE DOMAIN schema_1.text AS text"
  execute "CREATE DOMAIN schema_1.varchar AS varchar"
  execute "CREATE DOMAIN schema_1.bpchar AS bpchar"

  execute <<_SQL
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
_SQL

  execute <<_SQL
  CREATE TABLE postgresql_arrays (
    id SERIAL PRIMARY KEY,
    commission_by_quarter INTEGER[],
    nicknames TEXT[]
  );
_SQL

  execute <<_SQL
  CREATE TABLE postgresql_tsvectors (
    id SERIAL PRIMARY KEY,
    text_vector tsvector
  );
_SQL

  execute <<_SQL
  CREATE TABLE postgresql_moneys (
    id SERIAL PRIMARY KEY,
    wealth MONEY
  );
_SQL

  execute <<_SQL
  CREATE TABLE postgresql_numbers (
    id SERIAL PRIMARY KEY,
    single REAL,
    double DOUBLE PRECISION
  );
_SQL

  execute <<_SQL
  CREATE TABLE postgresql_times (
    id SERIAL PRIMARY KEY,
    time_interval INTERVAL
  );
_SQL

  execute <<_SQL
  CREATE TABLE postgresql_network_addresses (
    id SERIAL PRIMARY KEY,
    cidr_address CIDR,
    inet_address INET,
    mac_address MACADDR
  );
_SQL

  execute <<_SQL
  CREATE TABLE postgresql_bit_strings (
    id SERIAL PRIMARY KEY,
    bit_string BIT(8),
    bit_string_varying BIT VARYING(8)
  );
_SQL

  execute <<_SQL
  CREATE TABLE postgresql_oids (
    id SERIAL PRIMARY KEY,
    obj_id OID
  );
_SQL

  execute <<_SQL
  CREATE TABLE postgresql_timestamp_with_zones (
    id SERIAL PRIMARY KEY,
    time TIMESTAMP WITH TIME ZONE
  );
_SQL

  begin
    execute <<_SQL
    CREATE TABLE postgresql_xml_data_type (
    id SERIAL PRIMARY KEY,
    data xml
    );
_SQL
rescue #This version of PostgreSQL either has no XML support or is was not compiled with XML support: skipping table
  end

  create_table :limitless_fields, :force => true do |t|
    t.binary :binary, :limit => 100_000
    t.text :text, :limit => 100_000
  end
end

