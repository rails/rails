require 'cases/helper'

unless defined?(FireRuby::Database)
module FireRuby
  module Database; end
end
end

module ActiveRecord
  module FirebirdSetupper
    def setup
      @database      = 'db.firebird'
      @connection    = stub :connection
      @configuration = {
        'adapter'  => 'firebird',
        'database' => @database
      }
      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)

      @tasks = Class.new(ActiveRecord::Tasks::FirebirdDatabaseTasks) do
        def initialize(configuration)
          ActiveSupport::Deprecation.silence { super }
        end
      end
      ActiveRecord::Tasks::DatabaseTasks.stubs(:class_for_adapter).returns(@tasks) unless defined? ActiveRecord::ConnectionAdapters::FirebirdAdapter
    end
  end

  class FirebirdDBCreateTest < ActiveRecord::TestCase
    include FirebirdSetupper

    def test_db_retrieves_create
      message = capture(:stderr) do
        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end
      assert_match(/not supported/, message)
    end
  end
 
  class FirebirdDBDropTest < ActiveRecord::TestCase
    include FirebirdSetupper

    def test_db_retrieves_drop
      message = capture(:stderr) do
        ActiveRecord::Tasks::DatabaseTasks.drop @configuration
      end
      assert_match(/not supported/, message)
    end
  end
 
  class FirebirdDBCharsetAndCollationTest < ActiveRecord::TestCase
    include FirebirdSetupper

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

  class FirebirdStructureDumpTest < ActiveRecord::TestCase
    include FirebirdSetupper

    def setup
      super
      FireRuby::Database.stubs(:db_string_for).returns(@database)
    end

    def test_structure_dump
      filename = "filebird.sql"
      Kernel.expects(:system).with("isql -a #{@database} > #{filename}")

      ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
    end
  end

  class FirebirdStructureLoadTest < ActiveRecord::TestCase
    include FirebirdSetupper

    def setup
      super
      FireRuby::Database.stubs(:db_string_for).returns(@database)
    end

    def test_structure_load
      filename = "firebird.sql"
      Kernel.expects(:system).with("isql -i #{filename} #{@database}")

      ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
    end
  end
end
