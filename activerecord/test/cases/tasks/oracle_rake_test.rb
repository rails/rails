require 'cases/helper'

module ActiveRecord
  module OracleSetupper
    def setup
      @database      = 'db.oracle'
      @connection    = stub :connection
      @configuration = {
        'adapter'  => 'oracle',
        'database' => @database
      }
      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)

      @tasks = Class.new(ActiveRecord::Tasks::OracleDatabaseTasks) do
        def initialize(configuration)
          ActiveSupport::Deprecation.silence { super }
        end
      end
      ActiveRecord::Tasks::DatabaseTasks.stubs(:class_for_adapter).returns(@tasks) unless defined? ActiveRecord::ConnectionAdapters::OracleAdapter
    end
  end

  class OracleDBCreateTest < ActiveRecord::TestCase
    include OracleSetupper

    def test_db_retrieves_create
      message = capture(:stderr) do
        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end
      assert_match(/not supported/, message)
    end
  end

  class OracleDBDropTest < ActiveRecord::TestCase
    include OracleSetupper

    def test_db_retrieves_drop
      message = capture(:stderr) do
        ActiveRecord::Tasks::DatabaseTasks.drop @configuration
      end
      assert_match(/not supported/, message)
    end
  end

  class OracleDBCharsetAndCollationTest < ActiveRecord::TestCase
    include OracleSetupper

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

  class OracleStructureDumpTest < ActiveRecord::TestCase
    include OracleSetupper

    def setup
      super
      @connection.stubs(:structure_dump).returns("select sysdate from dual;")
    end

    def test_structure_dump
      filename = "oracle.sql"
      ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
      assert File.exist?(filename)
    ensure
      FileUtils.rm_f(filename)
    end
  end

  class OracleStructureLoadTest < ActiveRecord::TestCase
    include OracleSetupper

    def test_structure_load
      filename = "oracle.sql"

      open(filename, 'w') { |f| f.puts("select sysdate from dual;") }
      @connection.stubs(:execute).with("select sysdate from dual;\n")
      ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
    ensure
      FileUtils.rm_f(filename)
    end
  end
end
