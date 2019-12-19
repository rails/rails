# frozen_string_literal: true

ActiveRecord::Schema.define do
  execute "drop table test_oracle_defaults" rescue nil
  execute "drop sequence test_oracle_defaults_seq" rescue nil
  execute "drop sequence companies_nonstd_seq" rescue nil
  execute "drop table defaults" rescue nil
  execute "drop sequence defaults_seq" rescue nil

  execute <<~SQL
    create table test_oracle_defaults (
      id integer not null primary key,
      test_char char(1) default 'X' not null,
      test_string varchar2(20) default 'hello' not null,
      test_int integer default 3 not null
    )
  SQL

  execute "create sequence test_oracle_defaults_seq minvalue 10000"

  execute "create sequence companies_nonstd_seq minvalue 10000"

  execute <<~SQL
    CREATE TABLE defaults (
      id integer not null,
      modified_date date default sysdate,
      modified_date_function date default sysdate,
      fixed_date date default to_date('2004-01-01', 'YYYY-MM-DD'),
      modified_time date default sysdate,
      modified_time_function date default sysdate,
      fixed_time date default TO_DATE('2004-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS'),
      char1 varchar2(1) default 'Y',
      char2 varchar2(50) default 'a varchar field',
      char3 clob default 'a text field'
    )
  SQL
  execute "create sequence defaults_seq minvalue 10000"
end
