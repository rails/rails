require "cases/helper"

class ActiveSchemaTest < ActiveRecord::TestCase
  def setup
    ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval do
      alias_method :execute_without_stub, :execute
      def execute(sql, name = nil) return sql end
    end
  end

  def teardown
    ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval do
      remove_method :execute
      alias_method :execute, :execute_without_stub
    end
  end

  def test_drop_table
    assert_equal "DROP TABLE `people`", drop_table(:people)
  end

  if current_adapter?(:MysqlAdapter)
    def test_create_mysql_database_with_encoding
      assert_equal "CREATE DATABASE `matt` DEFAULT CHARACTER SET `utf8`", create_database(:matt)
      assert_equal "CREATE DATABASE `aimonetti` DEFAULT CHARACTER SET `latin1`", create_database(:aimonetti, {:charset => 'latin1'})
      assert_equal "CREATE DATABASE `matt_aimonetti` DEFAULT CHARACTER SET `big5` COLLATE `big5_chinese_ci`", create_database(:matt_aimonetti, {:charset => :big5, :collation => :big5_chinese_ci})
    end

    def test_recreate_mysql_database_with_encoding
      create_database(:luca, {:charset => 'latin1'})
      assert_equal "CREATE DATABASE `luca` DEFAULT CHARACTER SET `latin1`", recreate_database(:luca, {:charset => 'latin1'})
    end
  end

  def test_add_column
    assert_equal "ALTER TABLE `people` ADD `last_name` varchar(255)", add_column(:people, :last_name, :string)
  end

  def test_add_column_with_limit
    assert_equal "ALTER TABLE `people` ADD `key` varchar(32)", add_column(:people, :key, :string, :limit => 32)
  end

  def test_drop_table_with_specific_database
    assert_equal "DROP TABLE `otherdb`.`people`", drop_table('otherdb.people')
  end

  def test_add_timestamps 
    with_real_execute do
      begin
        ActiveRecord::Base.connection.create_table :delete_me do |t|
        end
        ActiveRecord::Base.connection.add_timestamps :delete_me
        assert column_present?('delete_me', 'updated_at', 'datetime')
        assert column_present?('delete_me', 'created_at', 'datetime')
      ensure
        ActiveRecord::Base.connection.drop_table :delete_me rescue nil
      end
    end
  end
  
  def test_remove_timestamps 
    with_real_execute do
      begin
        ActiveRecord::Base.connection.create_table :delete_me do |t|
          t.timestamps
        end
        ActiveRecord::Base.connection.remove_timestamps :delete_me
        assert !column_present?('delete_me', 'updated_at', 'datetime')
        assert !column_present?('delete_me', 'created_at', 'datetime')
      ensure
        ActiveRecord::Base.connection.drop_table :delete_me rescue nil
      end
    end
  end

  private
    def with_real_execute
      #we need to actually modify some data, so we make execute point to the original method
      ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval do
        alias_method :execute_with_stub, :execute
        alias_method :execute, :execute_without_stub
      end
      yield
    ensure
      #before finishing, we restore the alias to the mock-up method
      ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval do
        alias_method :execute, :execute_with_stub
      end
    end


    def method_missing(method_symbol, *arguments)
      ActiveRecord::Base.connection.send(method_symbol, *arguments)
    end

    def column_present?(table_name, column_name, type)
      results = ActiveRecord::Base.connection.select_all("SHOW FIELDS FROM #{table_name} LIKE '#{column_name}'")
      results.first && results.first['Type'] == type
    end
end
