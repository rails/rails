# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

class Mysql2TableOptionsTest < ActiveRecord::Mysql2TestCase
  include ConnectionHelper

  def setup
    ActiveRecord::Base.connection.singleton_class.class_eval do
      alias_method :execute_without_stub, :execute
      def execute(sql, name = nil) return sql end
    end
  end

  def teardown
    reset_connection
  end

  test "table default options" do
    actual = ActiveRecord::Base.connection.create_table "mysql_table_options", id: false, force: true
    expected = "CREATE TABLE `mysql_table_options`  ENGINE=InnoDB"
    assert_equal expected, actual
  end

  test "table options with ENGINE" do
    actual = ActiveRecord::Base.connection.create_table "mysql_table_options", id: false, force: true, options: "ENGINE=MyISAM"
    expected = "CREATE TABLE `mysql_table_options`  ENGINE=MyISAM"
    assert_equal expected, actual
  end

  test "table options with ROW_FORMAT" do
    actual = ActiveRecord::Base.connection.create_table "mysql_table_options", id: false, force: true, options: "ROW_FORMAT=REDUNDANT"
    expected = "CREATE TABLE `mysql_table_options`  ENGINE=InnoDB ROW_FORMAT=REDUNDANT"
    assert_equal expected, actual
  end

  test "table options with CHARSET" do
    actual = ActiveRecord::Base.connection.create_table "mysql_table_options", id: false, force: true, options: "CHARSET=utf8mb4"
    expected = "CREATE TABLE `mysql_table_options`  ENGINE=InnoDB CHARSET=utf8mb4"
    assert_equal expected, actual
  end

  test "table options with COLLATE" do
    actual = ActiveRecord::Base.connection.create_table "mysql_table_options", id: false, force: true, options: "COLLATE=utf8mb4_bin"
    expected = "CREATE TABLE `mysql_table_options`  ENGINE=InnoDB COLLATE=utf8mb4_bin"
    assert_equal expected, actual
  end

  test "table options with COLLATE and ENGINE" do
    actual = ActiveRecord::Base.connection.create_table "mysql_table_options", id: false, force: true, options: "ENGINE=MyISAM COLLATE=utf8mb4_bin"
    expected = "CREATE TABLE `mysql_table_options`  ENGINE=MyISAM COLLATE=utf8mb4_bin"
    assert_equal expected, actual
  end
end
