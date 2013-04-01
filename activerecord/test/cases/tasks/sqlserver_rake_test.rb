require 'cases/helper'

module ActiveRecord
  module SqlserverSetupper
    def setup
      @database      = 'db.sqlserver'
      @connection    = stub :connection
      @configuration = {
        'adapter'  => 'sqlserver',
        'database' => @database,
        'host'     => 'localhost',
        'username' => 'username',
        'password' => 'password',
      }
      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)

      @tasks = Class.new(ActiveRecord::Tasks::SqlserverDatabaseTasks) do
        def initialize(configuration)
          ActiveSupport::Deprecation.silence { super }
        end
      end
      ActiveRecord::Tasks::DatabaseTasks.stubs(:class_for_adapter).returns(@tasks) unless defined? ActiveRecord::ConnectionAdapters::SQLServerAdapter
    end
  end

  class SqlserverDBCreateTest < ActiveRecord::TestCase
    include SqlserverSetupper

    def test_db_retrieves_create
      message = capture(:stderr) do
        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end
      assert_match(/not supported/, message)
    end
  end
 
  class SqlserverDBDropTest < ActiveRecord::TestCase
    include SqlserverSetupper

    def test_db_retrieves_drop
      message = capture(:stderr) do
        ActiveRecord::Tasks::DatabaseTasks.drop @configuration
      end
      assert_match(/not supported/, message)
    end
  end
 
  class SqlserverDBCharsetAndCollationTest < ActiveRecord::TestCase
    include SqlserverSetupper

    def test_db_retrieves_collation
      assert_raise NoMethodError do
        ActiveRecord::Tasks::DatabaseTasks.collation @configuration
      end
    end

    def test_db_retrieves_charset
      message = capture(:stderr) do
        ActiveRecord::Tasks::DatabaseTasks.charset @configuration
      end
      assert_match(/not supported/, message)
    end
  end

  class SqlserverStructureDumpTest < ActiveRecord::TestCase
    include SqlserverSetupper

    def test_structure_dump
      filename = "sqlserver.sql"
      Kernel.expects(:system).with("smoscript -s localhost -d #{@database} -u username -p password -f #{filename} -A -U")

      ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
    end
  end

  class SqlserverStructureLoadTest < ActiveRecord::TestCase
    include SqlserverSetupper

    def test_structure_load
      filename = "sqlserver.sql"
      Kernel.expects(:system).with("sqlcmd -S localhost -d #{@database} -U username -P password -i #{filename}")

      ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
    end
  end
end
