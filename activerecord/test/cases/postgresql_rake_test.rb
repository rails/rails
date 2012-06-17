require 'cases/helper'

module ActiveRecord
  class PostgreSQLDBCreateTest < ActiveRecord::TestCase
    def setup
      @connection    = stub(:create_database => true)
      @configuration = {
        'adapter'  => 'postgresql',
        'database' => 'my-app-db'
      }

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_establishes_connection_to_postgresql_database
      ActiveRecord::Base.expects(:establish_connection).with(
        'adapter'            => 'postgresql',
        'database'           => 'postgres',
        'schema_search_path' => 'public'
      )

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end

    def test_creates_database_with_default_encoding
      @connection.expects(:create_database).
        with('my-app-db', @configuration.merge('encoding' => 'utf8'))

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end

    def test_creates_database_with_given_encoding
      @connection.expects(:create_database).
        with('my-app-db', @configuration.merge('encoding' => 'latin'))

      ActiveRecord::Tasks::DatabaseTasks.create @configuration.
        merge('encoding' => 'latin')
    end

    def test_establishes_connection_to_new_database
      ActiveRecord::Base.expects(:establish_connection).with(@configuration)

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end

    def test_db_create_with_error_prints_message
      ActiveRecord::Base.stubs(:establish_connection).raises(Exception)

      $stderr.stubs(:puts).returns(true)
      $stderr.expects(:puts).
        with("Couldn't create database for #{@configuration.inspect}")

      ActiveRecord::Tasks::DatabaseTasks.create @configuration
    end
  end
end
