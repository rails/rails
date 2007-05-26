require 'abstract_unit'

class ActiveSchemaTest < Test::Unit::TestCase
  def setup
    ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval do
      alias_method :real_execute, :execute
      def execute(sql, name = nil) return sql end
    end
  end

  def teardown
    ActiveRecord::ConnectionAdapters::MysqlAdapter.send(:alias_method, :execute, :real_execute)
  end

  def test_drop_table
    assert_equal "DROP TABLE people", drop_table(:people)
  end

  if current_adapter?(:MysqlAdapter)
    def test_create_mysql_database_with_encoding
      assert_equal "CREATE DATABASE `matt` DEFAULT CHARACTER SET `utf8`", create_database(:matt)
      assert_equal "CREATE DATABASE `aimonetti` DEFAULT CHARACTER SET `latin1`", create_database(:aimonetti, {:charset => 'latin1'})
      assert_equal "CREATE DATABASE `matt_aimonetti` DEFAULT CHARACTER SET `big5` COLLATE `big5_chinese_ci`", create_database(:matt_aimonetti, {:charset => :big5, :collation => :big5_chinese_ci})
    end
  end

  def test_add_column
    assert_equal "ALTER TABLE people ADD `last_name` varchar(255)", add_column(:people, :last_name, :string)
  end

  def test_add_column_with_limit
    assert_equal "ALTER TABLE people ADD `key` varchar(32)", add_column(:people, :key, :string, :limit => 32)
  end

  private
    def method_missing(method_symbol, *arguments)
      ActiveRecord::Base.connection.send(method_symbol, *arguments)
    end
end
