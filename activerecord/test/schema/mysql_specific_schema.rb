ActiveRecord::Schema.define do
  create_table :binary_fields, force: true do |t|
    t.binary :var_binary, limit: 255
    t.binary :var_binary_large, limit: 4095
    t.column :tiny_blob, 'tinyblob', limit: 255
    t.binary :normal_blob, limit: 65535
    t.binary :medium_blob, limit: 16777215
    t.binary :long_blob, limit: 2147483647
    t.text   :tiny_text, limit: 255
    t.text   :normal_text, limit: 65535
    t.text   :medium_text, limit: 16777215
    t.text   :long_text, limit: 2147483647
  end

  add_index :binary_fields, :var_binary

  create_table :key_tests, force: true, :options => 'ENGINE=MyISAM' do |t|
    t.string :awesome
    t.string :pizza
    t.string :snacks
  end

  add_index :key_tests, :awesome, :type => :fulltext, :name => 'index_key_tests_on_awesome'
  add_index :key_tests, :pizza, :using => :btree, :name => 'index_key_tests_on_pizza'
  add_index :key_tests, :snacks, :name => 'index_key_tests_on_snack'

  ActiveRecord::Base.connection.execute <<-SQL
DROP PROCEDURE IF EXISTS ten;
SQL

  ActiveRecord::Base.connection.execute <<-SQL
CREATE PROCEDURE ten() SQL SECURITY INVOKER
BEGIN
	select 10;
END
SQL

  ActiveRecord::Base.connection.execute <<-SQL
DROP PROCEDURE IF EXISTS topics;
SQL

  ActiveRecord::Base.connection.execute <<-SQL
CREATE PROCEDURE topics() SQL SECURITY INVOKER
BEGIN
	select * from topics limit 1;
END
SQL

  ActiveRecord::Base.connection.execute <<-SQL
DROP TABLE IF EXISTS collation_tests;
SQL

  ActiveRecord::Base.connection.execute <<-SQL
CREATE TABLE collation_tests (
  string_cs_column VARCHAR(1) COLLATE utf8_bin,
  string_ci_column VARCHAR(1) COLLATE utf8_general_ci
) CHARACTER SET utf8 COLLATE utf8_general_ci
SQL

  ActiveRecord::Base.connection.execute <<-SQL
DROP TABLE IF EXISTS enum_tests;
SQL

  ActiveRecord::Base.connection.execute <<-SQL
CREATE TABLE enum_tests (
  enum_column ENUM('true','false')
)
SQL

end
