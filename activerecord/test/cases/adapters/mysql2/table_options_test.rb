# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class Mysql2TableOptionsTest < ActiveRecord::Mysql2TestCase
  include SchemaDumpingHelper

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    @connection.drop_table "mysql_table_options", if_exists: true
  end

  test "table options with ENGINE" do
    @connection.create_table "mysql_table_options", force: true, options: "ENGINE=MyISAM"
    output = dump_table_schema("mysql_table_options")
    options = %r{create_table "mysql_table_options", options: "(?<options>.*)"}.match(output)[:options]
    assert_match %r{ENGINE=MyISAM}, options
  end

  test "table options with ROW_FORMAT" do
    @connection.create_table "mysql_table_options", force: true, options: "ROW_FORMAT=REDUNDANT"
    output = dump_table_schema("mysql_table_options")
    options = %r{create_table "mysql_table_options", options: "(?<options>.*)"}.match(output)[:options]
    assert_match %r{ROW_FORMAT=REDUNDANT}, options
  end

  test "table options with CHARSET" do
    @connection.create_table "mysql_table_options", force: true, options: "CHARSET=utf8mb4"
    output = dump_table_schema("mysql_table_options")
    options = %r{create_table "mysql_table_options", options: "(?<options>.*)"}.match(output)[:options]
    assert_match %r{CHARSET=utf8mb4}, options
  end

  test "table options with COLLATE" do
    @connection.create_table "mysql_table_options", force: true, options: "COLLATE=utf8mb4_bin"
    output = dump_table_schema("mysql_table_options")
    options = %r{create_table "mysql_table_options", options: "(?<options>.*)"}.match(output)[:options]
    assert_match %r{COLLATE=utf8mb4_bin}, options
  end
end

class Mysql2DefaultEngineOptionSchemaDumpTest < ActiveRecord::Mysql2TestCase
  include SchemaDumpingHelper
  self.use_transactional_tests = false

  def setup
    @verbose_was = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  def teardown
    ActiveRecord::Base.connection.drop_table "mysql_table_options", if_exists: true
    ActiveRecord::Migration.verbose = @verbose_was
    ActiveRecord::SchemaMigration.delete_all rescue nil
  end

  test "schema dump includes ENGINE=InnoDB if not provided" do
    ActiveRecord::Base.connection.create_table "mysql_table_options", force: true

    output  = dump_table_schema("mysql_table_options")
    options = %r{create_table "mysql_table_options", options: "(?<options>.*)"}.match(output)[:options]
    assert_match %r{ENGINE=InnoDB}, options
  end

  test "schema dump includes ENGINE=InnoDB in legacy migrations" do
    migration = Class.new(ActiveRecord::Migration[5.1]) do
      def migrate(x)
        create_table "mysql_table_options", force: true
      end
    end.new

    ActiveRecord::Migrator.new(:up, [migration]).migrate

    output  = dump_table_schema("mysql_table_options")
    options = %r{create_table "mysql_table_options", options: "(?<options>.*)"}.match(output)[:options]
    assert_match %r{ENGINE=InnoDB}, options
  end
end

class Mysql2DefaultEngineOptionSqlOutputTest < ActiveRecord::Mysql2TestCase
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
    ActiveRecord::SchemaMigration.delete_all rescue nil
  end

  test "new migrations do not contain default ENGINE=InnoDB option" do
    ActiveRecord::Base.connection.create_table "mysql_table_options", force: true

    assert_no_match %r{ENGINE=InnoDB}, @log.string
  end

  test "legacy migrations contain default ENGINE=InnoDB option" do
    migration = Class.new(ActiveRecord::Migration[5.1]) do
      def migrate(x)
        create_table "mysql_table_options", force: true
      end
    end.new

    ActiveRecord::Migrator.new(:up, [migration]).migrate

    assert_match %r{ENGINE=InnoDB}, @log.string
  end
end
