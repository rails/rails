ActiveRecord::Schema.define do
  create_table :table_with_autoincrement, :force => true do |t|
    t.column :name, :string
  end

  execute "DROP TABLE fk_test_has_fk" rescue nil
  execute "DROP TABLE fk_test_has_pk" rescue nil
  execute <<_SQL
  CREATE TABLE 'fk_test_has_pk' (
    'id' INTEGER NOT NULL PRIMARY KEY
  );
_SQL

  execute <<_SQL
  CREATE TABLE 'fk_test_has_fk' (
    'id'    INTEGER NOT NULL PRIMARY KEY,
    'fk_id' INTEGER NOT NULL,

    FOREIGN KEY ('fk_id') REFERENCES 'fk_test_has_pk'('id')
  );
_SQL
end