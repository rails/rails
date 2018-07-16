# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

class Mysql2ActiveSchemaTest < ActiveRecord::Mysql2TestCase
  include ConnectionHelper

  def setup
    ActiveRecord::Base.connection.singleton_class.class_eval do
      alias_method :execute_without_stub, :execute
      def execute(sql, name = nil) sql end
    end
  end

  teardown do
    reset_connection
  end

  def test_add_index
    # add_index calls data_source_exists? and index_name_exists? which can't work since execute is stubbed
    def (ActiveRecord::Base.connection).data_source_exists?(*); true; end
    def (ActiveRecord::Base.connection).index_name_exists?(*); false; end

    expected = "CREATE  INDEX `index_people_on_last_name`  ON `people` (`last_name`) "
    assert_equal expected, add_index(:people, :last_name, length: nil)

    expected = "CREATE  INDEX `index_people_on_last_name`  ON `people` (`last_name`(10)) "
    assert_equal expected, add_index(:people, :last_name, length: 10)

    expected = "CREATE  INDEX `index_people_on_last_name_and_first_name`  ON `people` (`last_name`(15), `first_name`(15)) "
    assert_equal expected, add_index(:people, [:last_name, :first_name], length: 15)
    assert_equal expected, add_index(:people, ["last_name", "first_name"], length: 15)

    expected = "CREATE  INDEX `index_people_on_last_name_and_first_name`  ON `people` (`last_name`(15), `first_name`) "
    assert_equal expected, add_index(:people, [:last_name, :first_name], length: { last_name: 15 })
    assert_equal expected, add_index(:people, ["last_name", "first_name"], length: { last_name: 15 })

    expected = "CREATE  INDEX `index_people_on_last_name_and_first_name`  ON `people` (`last_name`(15), `first_name`(10)) "
    assert_equal expected, add_index(:people, [:last_name, :first_name], length: { last_name: 15, first_name: 10 })
    assert_equal expected, add_index(:people, ["last_name", :first_name], length: { last_name: 15, "first_name" => 10 })

    %w(SPATIAL FULLTEXT UNIQUE).each do |type|
      expected = "CREATE #{type} INDEX `index_people_on_last_name`  ON `people` (`last_name`) "
      assert_equal expected, add_index(:people, :last_name, type: type)
    end

    %w(btree hash).each do |using|
      expected = "CREATE  INDEX `index_people_on_last_name` USING #{using} ON `people` (`last_name`) "
      assert_equal expected, add_index(:people, :last_name, using: using)
    end

    expected = "CREATE  INDEX `index_people_on_last_name` USING btree ON `people` (`last_name`(10)) "
    assert_equal expected, add_index(:people, :last_name, length: 10, using: :btree)

    expected = "CREATE  INDEX `index_people_on_last_name` USING btree ON `people` (`last_name`(10)) ALGORITHM = COPY"
    assert_equal expected, add_index(:people, :last_name, length: 10, using: :btree, algorithm: :copy)

    assert_raise ArgumentError do
      add_index(:people, :last_name, algorithm: :coyp)
    end

    expected = "CREATE  INDEX `index_people_on_last_name_and_first_name` USING btree ON `people` (`last_name`(15), `first_name`(15)) "
    assert_equal expected, add_index(:people, [:last_name, :first_name], length: 15, using: :btree)
  end

  def test_index_in_create
    def (ActiveRecord::Base.connection).data_source_exists?(*); false; end

    %w(SPATIAL FULLTEXT UNIQUE).each do |type|
      expected = "CREATE TABLE `people` (#{type} INDEX `index_people_on_last_name`  (`last_name`))"
      actual = ActiveRecord::Base.connection.create_table(:people, id: false) do |t|
        t.index :last_name, type: type
      end
      assert_equal expected, actual
    end

    expected = "CREATE TABLE `people` ( INDEX `index_people_on_last_name` USING btree (`last_name`(10)))"
    actual = ActiveRecord::Base.connection.create_table(:people, id: false) do |t|
      t.index :last_name, length: 10, using: :btree
    end
    assert_equal expected, actual
  end

  def test_index_in_bulk_change
    def (ActiveRecord::Base.connection).data_source_exists?(*); true; end
    def (ActiveRecord::Base.connection).index_name_exists?(*); false; end

    %w(SPATIAL FULLTEXT UNIQUE).each do |type|
      expected = "ALTER TABLE `people` ADD #{type} INDEX `index_people_on_last_name`  (`last_name`)"
      actual = ActiveRecord::Base.connection.change_table(:people, bulk: true) do |t|
        t.index :last_name, type: type
      end
      assert_equal expected, actual
    end

    expected = "ALTER TABLE `people` ADD  INDEX `index_people_on_last_name` USING btree (`last_name`(10)), ALGORITHM = COPY"
    actual = ActiveRecord::Base.connection.change_table(:people, bulk: true) do |t|
      t.index :last_name, length: 10, using: :btree, algorithm: :copy
    end
    assert_equal expected, actual
  end

  def test_drop_table
    assert_equal "DROP TABLE `people`", drop_table(:people)
  end

  def test_create_mysql_database_with_encoding
    assert_equal "CREATE DATABASE `matt` DEFAULT CHARACTER SET `utf8`", create_database(:matt)
    assert_equal "CREATE DATABASE `aimonetti` DEFAULT CHARACTER SET `latin1`", create_database(:aimonetti, charset: "latin1")
    assert_equal "CREATE DATABASE `matt_aimonetti` DEFAULT COLLATE `utf8mb4_bin`", create_database(:matt_aimonetti, collation: "utf8mb4_bin")
  end

  def test_recreate_mysql_database_with_encoding
    create_database(:luca, charset: "latin1")
    assert_equal "CREATE DATABASE `luca` DEFAULT CHARACTER SET `latin1`", recreate_database(:luca, charset: "latin1")
  end

  def test_add_column
    assert_equal "ALTER TABLE `people` ADD `last_name` varchar(255)", add_column(:people, :last_name, :string)
  end

  def test_add_column_with_limit
    assert_equal "ALTER TABLE `people` ADD `key` varchar(32)", add_column(:people, :key, :string, limit: 32)
  end

  def test_drop_table_with_specific_database
    assert_equal "DROP TABLE `otherdb`.`people`", drop_table("otherdb.people")
  end

  def test_add_timestamps
    with_real_execute do
      begin
        ActiveRecord::Base.connection.create_table :delete_me
        ActiveRecord::Base.connection.add_timestamps :delete_me, null: true
        assert column_present?("delete_me", "updated_at", "datetime")
        assert column_present?("delete_me", "created_at", "datetime")
      ensure
        ActiveRecord::Base.connection.drop_table :delete_me rescue nil
      end
    end
  end

  def test_remove_timestamps
    with_real_execute do
      begin
        ActiveRecord::Base.connection.create_table :delete_me do |t|
          t.timestamps null: true
        end
        ActiveRecord::Base.connection.remove_timestamps :delete_me, null: true
        assert_not column_present?("delete_me", "updated_at", "datetime")
        assert_not column_present?("delete_me", "created_at", "datetime")
      ensure
        ActiveRecord::Base.connection.drop_table :delete_me rescue nil
      end
    end
  end

  def test_indexes_in_create
    ActiveRecord::Base.connection.stubs(:data_source_exists?).with(:temp).returns(false)

    expected = "CREATE TEMPORARY TABLE `temp` ( INDEX `index_temp_on_zip`  (`zip`)) AS SELECT id, name, zip FROM a_really_complicated_query"
    actual = ActiveRecord::Base.connection.create_table(:temp, temporary: true, as: "SELECT id, name, zip FROM a_really_complicated_query") do |t|
      t.index :zip
    end

    assert_equal expected, actual
  end

  private
    def with_real_execute
      ActiveRecord::Base.connection.singleton_class.class_eval do
        alias_method :execute_with_stub, :execute
        remove_method :execute
        alias_method :execute, :execute_without_stub
      end

      yield
    ensure
      ActiveRecord::Base.connection.singleton_class.class_eval do
        remove_method :execute
        alias_method :execute, :execute_with_stub
      end
    end

    def method_missing(method_symbol, *arguments)
      ActiveRecord::Base.connection.send(method_symbol, *arguments)
    end

    def column_present?(table_name, column_name, type)
      results = ActiveRecord::Base.connection.select_all("SHOW FIELDS FROM #{table_name} LIKE '#{column_name}'")
      results.first && results.first["Type"] == type
    end
end
