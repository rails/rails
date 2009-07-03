ActiveRecord::Schema.define do

  execute "drop table test_oracle_defaults" rescue nil
  execute "drop sequence test_oracle_defaults_seq" rescue nil

  execute <<-SQL
create table test_oracle_defaults (
  id integer not null primary key,
  test_char char(1) default 'X' not null,
  test_string varchar2(20) default 'hello' not null,
  test_int integer default 3 not null
)
  SQL

  execute <<-SQL
create sequence test_oracle_defaults_seq minvalue 10000
  SQL

end
