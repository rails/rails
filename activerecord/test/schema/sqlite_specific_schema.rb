ActiveRecord::Schema.define do
  execute "DROP TABLE fk_test_has_fk" rescue nil
  execute "DROP TABLE fk_test_has_pk" rescue nil
  execute "DROP TABLE defaults" rescue nil
  execute <<_SQL
  CREATE TABLE 'fk_test_has_pk' (
    'pk_id' INTEGER NOT NULL PRIMARY KEY
  );
_SQL

  execute <<_SQL
  CREATE TABLE 'fk_test_has_fk' (
    'id'    INTEGER NOT NULL PRIMARY KEY,
    'fk_id' INTEGER NOT NULL,

    FOREIGN KEY ('fk_id') REFERENCES 'fk_test_has_pk'('pk_id')
  );
_SQL

  execute <<_SQL
  CREATE TABLE 'defaults' (
    'id'         INTEGER NOT NULL PRIMARY KEY,
    'fixed_date' DATE DEFAULT '2004-01-01',
    'fixed_time' DATETIME DEFAULT '2004-01-01 00:00:00',
    'char1'      CHAR(1) DEFAULT 'Y',
    'char2'      CHAR(50) DEFAULT 'a varchar field',
    'char3'      TEXT DEFAULT 'a text field'
  );
_SQL
end
