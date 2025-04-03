# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

class ActiveSchemaTest < ActiveRecord::AbstractMysqlTestCase
  include ConnectionHelper

  def setup
    ActiveRecord::Base.lease_connection.send(:default_row_format)
    ActiveRecord::Base.lease_connection.singleton_class.class_eval do
      alias_method :execute_without_stub, :execute
      def execute(sql, name = nil)
        ActiveSupport::Notifications.instrumenter.instrument(
          "sql.active_record",
          sql: sql,
          name: name,
          connection: self) do
          sql
        end
      end
    end
  end

  teardown do
    reset_connection
  end

  def test_add_index
    expected = "CREATE INDEX `index_people_on_last_name` ON `people` (`last_name`)"
    assert_equal expected, add_index(:people, :last_name, length: nil)

    expected = "CREATE INDEX `index_people_on_last_name` ON `people` (`last_name`(10))"
    assert_equal expected, add_index(:people, :last_name, length: 10)

    expected = "CREATE INDEX `index_people_on_last_name_and_first_name` ON `people` (`last_name`(15), `first_name`(15))"
    assert_equal expected, add_index(:people, [:last_name, :first_name], length: 15)
    assert_equal expected, add_index(:people, ["last_name", "first_name"], length: 15)

    expected = "CREATE INDEX `index_people_on_last_name_and_first_name` ON `people` (`last_name`(15), `first_name`)"
    assert_equal expected, add_index(:people, [:last_name, :first_name], length: { last_name: 15 })
    assert_equal expected, add_index(:people, ["last_name", "first_name"], length: { last_name: 15 })

    expected = "CREATE INDEX `index_people_on_last_name_and_first_name` ON `people` (`last_name`(15), `first_name`(10))"
    assert_equal expected, add_index(:people, [:last_name, :first_name], length: { last_name: 15, first_name: 10 })
    assert_equal expected, add_index(:people, ["last_name", :first_name], length: { last_name: 15, "first_name" => 10 })

    %w(SPATIAL FULLTEXT UNIQUE).each do |type|
      expected = "CREATE #{type} INDEX `index_people_on_last_name` ON `people` (`last_name`)"
      assert_equal expected, add_index(:people, :last_name, type: type)
    end

    %w(btree hash).each do |using|
      expected = "CREATE INDEX `index_people_on_last_name` USING #{using} ON `people` (`last_name`)"
      assert_equal expected, add_index(:people, :last_name, using: using)
    end

    expected = "CREATE INDEX `index_people_on_last_name` USING btree ON `people` (`last_name`(10))"
    assert_equal expected, add_index(:people, :last_name, length: 10, using: :btree)

    %i(default copy inplace instant).each do |algorithm|
      expected = "CREATE INDEX `index_people_on_last_name` USING btree ON `people` (`last_name`(10)) ALGORITHM = #{algorithm.upcase}"
      assert_equal expected, add_index(:people, :last_name, length: 10, using: :btree, algorithm: algorithm)
    end

    with_real_execute do
      add_index(:people, :first_name)
      assert index_exists?(:people, :first_name)

      assert_nothing_raised do
        add_index(:people, :first_name, if_not_exists: true)
      end
    end

    assert_raise ArgumentError do
      add_index(:people, :last_name, algorithm: :coyp)
    end

    expected = "CREATE INDEX `index_people_on_last_name_and_first_name` USING btree ON `people` (`last_name`(15), `first_name`(15))"
    assert_equal expected, add_index(:people, [:last_name, :first_name], length: 15, using: :btree)
  end

  def test_index_in_create
    %w(SPATIAL FULLTEXT UNIQUE).each do |type|
      expected = /\ACREATE TABLE `people` \(#{type} INDEX `index_people_on_last_name` \(`last_name`\)\)/
      actual = ActiveRecord::Base.lease_connection.create_table(:people, id: false) do |t|
        t.index :last_name, type: type
      end
      assert_match expected, actual
    end

    expected = /\ACREATE TABLE `people` \(INDEX `index_people_on_last_name` USING btree \(`last_name`\(10\)\)\)/
    actual = ActiveRecord::Base.lease_connection.create_table(:people, id: false) do |t|
      t.index :last_name, length: 10, using: :btree
    end
    assert_match expected, actual
  end

  def test_index_in_bulk_change
    %w(SPATIAL FULLTEXT UNIQUE).each do |type|
      expected = "ALTER TABLE `people` ADD #{type} INDEX `index_people_on_last_name` (`last_name`)"
      assert_queries_match(expected) do
        ActiveRecord::Base.lease_connection.change_table(:people, bulk: true) do |t|
          t.index :last_name, type: type
        end
      end
    end

    expected = "ALTER TABLE `people` ADD INDEX `index_people_on_last_name` USING btree (`last_name`(10)), ALGORITHM = COPY"
    assert_queries_match(expected) do
      ActiveRecord::Base.lease_connection.change_table(:people, bulk: true) do |t|
        t.index :last_name, length: 10, using: :btree, algorithm: :copy
      end
    end
  end

  def test_drop_table
    assert_equal "DROP TABLE `people`", drop_table(:people)
  end

  def test_drop_tables
    assert_equal "DROP TABLE `people`, `sobrinho`", drop_table(:people, :sobrinho)
  end

  def test_create_mysql_database_with_encoding
    if ActiveRecord::Base.lease_connection.send(:row_format_dynamic_by_default?)
      assert_equal "CREATE DATABASE `matt` DEFAULT CHARACTER SET `utf8mb4`", create_database(:matt)
    else
      error = assert_raises(RuntimeError) { create_database(:matt) }
      expected = "Configure a supported :charset and ensure innodb_large_prefix is enabled to support indexes on varchar(255) string columns."
      assert_equal expected, error.message
    end
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

  def test_drop_tables_with_specific_database
    assert_equal "DROP TABLE `otherdb`.`people`, `otherdb`.`sobrinho`", drop_table("otherdb.people", "otherdb.sobrinho")
  end

  def test_add_timestamps
    with_real_execute do
      ActiveRecord::Base.lease_connection.create_table :delete_me
      ActiveRecord::Base.lease_connection.add_timestamps :delete_me, null: true
      assert column_exists?("delete_me", "updated_at", "datetime")
      assert column_exists?("delete_me", "created_at", "datetime")
    ensure
      ActiveRecord::Base.lease_connection.drop_table :delete_me rescue nil
    end
  end

  def test_remove_timestamps
    with_real_execute do
      ActiveRecord::Base.lease_connection.create_table :delete_me do |t|
        t.timestamps null: true
      end
      ActiveRecord::Base.lease_connection.remove_timestamps :delete_me, null: true
      assert_not column_exists?("delete_me", "updated_at", "datetime")
      assert_not column_exists?("delete_me", "created_at", "datetime")
    ensure
      ActiveRecord::Base.lease_connection.drop_table :delete_me rescue nil
    end
  end

  def test_indexes_in_create
    expected = /\ACREATE TEMPORARY TABLE `temp` \(INDEX `index_temp_on_zip` \(`zip`\)\)(?: ROW_FORMAT=DYNAMIC)? AS SELECT id, name, zip FROM a_really_complicated_query/
    actual = ActiveRecord::Base.lease_connection.create_table(:temp, temporary: true, as: "SELECT id, name, zip FROM a_really_complicated_query") do |t|
      t.index :zip
    end

    assert_match expected, actual
  end

  private
    def with_real_execute
      ActiveRecord::Base.lease_connection.singleton_class.class_eval do
        alias_method :execute_with_stub, :execute
        remove_method :execute
        alias_method :execute, :execute_without_stub
      end

      yield
    ensure
      ActiveRecord::Base.lease_connection.singleton_class.class_eval do
        remove_method :execute
        alias_method :execute, :execute_with_stub
      end
    end

    def method_missing(...)
      ActiveRecord::Base.lease_connection.public_send(...)
    end
end
