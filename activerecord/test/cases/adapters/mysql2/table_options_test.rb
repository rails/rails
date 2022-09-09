# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class Mysql2TableOptionsTest < ActiveRecord::Mysql2TestCase
  include SchemaDumpingHelper
  self.use_transactional_tests = false

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    @connection.drop_table "mysql_table_options", if_exists: true
  end

  test "table options with ENGINE" do
    @connection.create_table "mysql_table_options", force: true, options: "ENGINE=MyISAM"
    output = dump_table_schema("mysql_table_options")
    expected = /create_table "mysql_table_options", charset: "utf8mb4"(?:, collation: "\w+")?, options: "ENGINE=MyISAM", force: :cascade/
    assert_match expected, output
  end

  test "table options with ROW_FORMAT" do
    @connection.create_table "mysql_table_options", force: true, options: "ROW_FORMAT=REDUNDANT"
    output = dump_table_schema("mysql_table_options")
    expected = /create_table "mysql_table_options", charset: "utf8mb4"(?:, collation: "\w+")?, options: "ENGINE=InnoDB ROW_FORMAT=REDUNDANT", force: :cascade/
    assert_match expected, output
  end

  test "table options with CHARSET" do
    @connection.create_table "mysql_table_options", force: true, options: "CHARSET=latin1"
    output = dump_table_schema("mysql_table_options")
    expected = /create_table "mysql_table_options", charset: "latin1", force: :cascade/
    assert_match expected, output
  end

  test "table options with COLLATE" do
    @connection.create_table "mysql_table_options", force: true, options: "COLLATE=utf8mb4_bin"
    output = dump_table_schema("mysql_table_options")
    expected = /create_table "mysql_table_options", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade/
    assert_match expected, output
  end

  test "charset and collation options" do
    @connection.create_table "mysql_table_options", force: true, charset: "utf8mb4", collation: "utf8mb4_bin"
    output = dump_table_schema("mysql_table_options")
    expected = /create_table "mysql_table_options", charset: "utf8mb4", collation: "utf8mb4_bin"(:?, options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC")?, force: :cascade/
    assert_match expected, output
  end

  test "charset and partitioned table options" do
    @connection.create_table "mysql_table_options", primary_key: ["id", "account_id"], charset: "utf8mb4", collation: "utf8mb4_bin", options: "ENGINE=InnoDB\n/*!50100 PARTITION BY HASH (`account_id`)\nPARTITIONS 128 */", force: :cascade do |t|
      t.bigint "id", null: false, auto_increment: true
      t.bigint "account_id", null: false, unsigned: true
    end
    output = dump_table_schema("mysql_table_options")
    expected = /create_table "mysql_table_options", primary_key: \["id", "account_id"\], charset: "utf8mb4", collation: "utf8mb4_bin", options: "ENGINE=InnoDB\\n(\/\*!50100)? PARTITION BY HASH \(`account_id`\)\\nPARTITIONS 128( \*\/)?", force: :cascade/
    assert_match expected, output
  end

  test "schema dump works with NO_TABLE_OPTIONS sql mode" do
    skip "As of MySQL 5.7.22, NO_TABLE_OPTIONS is deprecated. It will be removed in a future version of MySQL." if @connection.database_version >= "5.7.22"

    old_sql_mode = @connection.query_value("SELECT @@SESSION.sql_mode")
    new_sql_mode = old_sql_mode + ",NO_TABLE_OPTIONS"

    begin
      @connection.execute("SET @@SESSION.sql_mode='#{new_sql_mode}'")

      @connection.create_table "mysql_table_options", force: true
      output = dump_table_schema("mysql_table_options")
      assert_no_match %r{options:}, output
    ensure
      @connection.execute("SET @@SESSION.sql_mode='#{old_sql_mode}'")
    end
  end
end

class Mysql2DefaultEngineOptionTest < ActiveRecord::Mysql2TestCase
  include SchemaDumpingHelper
  self.use_transactional_tests = false

  def setup
    @logger_was  = ActiveRecord::Base.logger
    @log         = StringIO.new
    @verbose_was = ActiveRecord::Migration.verbose
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(@log)
    ActiveRecord::Migration.verbose = false
  end

  def teardown
    ActiveRecord::Base.logger       = @logger_was
    ActiveRecord::Migration.verbose = @verbose_was
    ActiveRecord::Base.connection.drop_table "mysql_table_options", if_exists: true
    ActiveRecord::Base.connection.schema_migration.delete_all_versions rescue nil
  end

  test "new migrations do not contain default ENGINE=InnoDB option" do
    ActiveRecord::Base.connection.create_table "mysql_table_options", force: true

    assert_no_match %r{ENGINE=InnoDB}, @log.string

    output = dump_table_schema("mysql_table_options")
    expected = /create_table "mysql_table_options", charset: "utf8mb4"(?:, collation: "\w+")?(:?, options: "ENGINE=InnoDB ROW_FORMAT=DYNAMIC")?, force: :cascade/
    assert_match expected, output
  end

  test "legacy migrations contain default ENGINE=InnoDB option" do
    migration = Class.new(ActiveRecord::Migration[5.1]) do
      def migrate(x)
        create_table "mysql_table_options", force: true
      end
    end.new

    connection = ActiveRecord::Base.connection
    ActiveRecord::Migrator.new(:up, [migration], connection.schema_migration, connection.internal_metadata).migrate

    assert_match %r{ENGINE=InnoDB}, @log.string

    output = dump_table_schema("mysql_table_options")
    expected = /create_table "mysql_table_options", charset: "utf8mb4"(?:, collation: "\w+")?, force: :cascade/
    assert_match expected, output
  end
end
