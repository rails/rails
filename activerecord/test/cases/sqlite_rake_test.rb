require 'cases/helper'

module ActiveRecord
  class SqliteDBCreateTest < ActiveRecord::TestCase
    def setup
      @database      = "db_create.sqlite3"
      @connection    = stub :connection
      @configuration = {
        'adapter'  => 'sqlite3',
        'database' => @database
      }

      File.stubs(:exist?).returns(false)
      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_db_checks_database_exists
      File.expects(:exist?).with(@database).returns(false)

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end

    def test_db_create_when_file_exists
      File.stubs(:exist?).returns(true)

      $stderr.expects(:puts).with("#{@database} already exists")

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end

    def test_db_create_with_file_does_nothing
      File.stubs(:exist?).returns(true)
      $stderr.stubs(:puts).returns(nil)

      ActiveRecord::Base.expects(:establish_connection).never

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end

    def test_db_create_establishes_a_connection
      ActiveRecord::Base.expects(:establish_connection).with(@configuration)

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end

    def test_db_create_returns_the_connection
      assert_equal ActiveRecord::Tasks::DatabaseTasks.create(@configuration),
        @connection
    end

    def test_db_create_with_error_prints_message
      ActiveRecord::Base.stubs(:establish_connection).raises(Exception)

      $stderr.stubs(:puts).returns(true)
      $stderr.expects(:puts).
        with("Couldn't create database for #{@configuration.inspect}")

      ActiveRecord::Tasks::DatabaseTasks.create(@configuration)
    end
  end
end
