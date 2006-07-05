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