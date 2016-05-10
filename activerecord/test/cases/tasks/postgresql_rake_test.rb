require 'cases/helper'
require 'active_record/tasks/database_tasks'

if current_adapter?(:PostgreSQLAdapter)
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

      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
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

    def test_creates_database_with_given_collation_and_ctype
      @connection.expects(:create_database).
        with('my-app-db', @configuration.merge('encoding' => 'utf8', 'collation' => 'ja_JP.UTF8', 'ctype' => 'ja_JP.UTF8'))

      ActiveRecord::Tasks::DatabaseTasks.create @configuration.
        merge('collation' => 'ja_JP.UTF8', 'ctype' => 'ja_JP.UTF8')
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

      assert_raises(Exception) { ActiveRecord::Tasks::DatabaseTasks.create @configuration }
    end

    def test_when_database_created_successfully_outputs_info_to_stdout
      ActiveRecord::Tasks::DatabaseTasks.create @configuration

      assert_equal $stdout.string, "Created database 'my-app-db'\n"
    end

    def test_create_when_database_exists_outputs_info_to_stderr
      ActiveRecord::Base.connection.stubs(:create_database).raises(
        ActiveRecord::Tasks::DatabaseAlreadyExists
      )

      ActiveRecord::Tasks::DatabaseTasks.create @configuration

      assert_equal $stderr.string, "Database 'my-app-db' already exists\n"
    end
  end

  class PostgreSQLDBDropTest < ActiveRecord::TestCase
    def setup
      @connection    = stub(:drop_database => true)
      @configuration = {
        'adapter'  => 'postgresql',
        'database' => 'my-app-db'
      }

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)

      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
    end

    def test_establishes_connection_to_postgresql_database
      ActiveRecord::Base.expects(:establish_connection).with(
        'adapter'            => 'postgresql',
        'database'           => 'postgres',
        'schema_search_path' => 'public'
      )

      ActiveRecord::Tasks::DatabaseTasks.drop @configuration
    end

    def test_drops_database
      @connection.expects(:drop_database).with('my-app-db')

      ActiveRecord::Tasks::DatabaseTasks.drop @configuration
    end

    def test_when_database_dropped_successfully_outputs_info_to_stdout
      ActiveRecord::Tasks::DatabaseTasks.drop @configuration

      assert_equal $stdout.string, "Dropped database 'my-app-db'\n"
    end
  end

  class PostgreSQLPurgeTest < ActiveRecord::TestCase
    def setup
      @connection    = stub(:create_database => true, :drop_database => true)
      @configuration = {
        'adapter'  => 'postgresql',
        'database' => 'my-app-db'
      }

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:clear_active_connections!).returns(true)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_clears_active_connections
      ActiveRecord::Base.expects(:clear_active_connections!)

      ActiveRecord::Tasks::DatabaseTasks.purge @configuration
    end

    def test_establishes_connection_to_postgresql_database
      ActiveRecord::Base.expects(:establish_connection).with(
        'adapter'            => 'postgresql',
        'database'           => 'postgres',
        'schema_search_path' => 'public'
      )

      ActiveRecord::Tasks::DatabaseTasks.purge @configuration
    end

    def test_drops_database
      @connection.expects(:drop_database).with('my-app-db')

      ActiveRecord::Tasks::DatabaseTasks.purge @configuration
    end

    def test_creates_database
      @connection.expects(:create_database).
        with('my-app-db', @configuration.merge('encoding' => 'utf8'))

      ActiveRecord::Tasks::DatabaseTasks.purge @configuration
    end

    def test_establishes_connection
      ActiveRecord::Base.expects(:establish_connection).with(@configuration)

      ActiveRecord::Tasks::DatabaseTasks.purge @configuration
    end
  end

  class PostgreSQLDBCharsetTest < ActiveRecord::TestCase
    def setup
      @connection    = stub(:create_database => true)
      @configuration = {
        'adapter'  => 'postgresql',
        'database' => 'my-app-db'
      }

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_db_retrieves_charset
      @connection.expects(:encoding)
      ActiveRecord::Tasks::DatabaseTasks.charset @configuration
    end
  end

  class PostgreSQLDBCollationTest < ActiveRecord::TestCase
    def setup
      @connection    = stub(:create_database => true)
      @configuration = {
        'adapter'  => 'postgresql',
        'database' => 'my-app-db'
      }

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_db_retrieves_collation
      @connection.expects(:collation)
      ActiveRecord::Tasks::DatabaseTasks.collation @configuration
    end
  end

  class PostgreSQLStructureDumpTest < ActiveRecord::TestCase
    def setup
      @connection    = stub(:structure_dump => true)
      @configuration = {
        'adapter'  => 'postgresql',
        'database' => 'my-app-db'
      }
      @filename = "awesome-file.sql"

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
      Kernel.stubs(:system)
      File.stubs(:open)
    end

    def test_structure_dump
      Kernel.expects(:system).with('pg_dump', '-s', '-x', '-O', '-f', @filename, 'my-app-db').returns(true)

      ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
    end

    def test_structure_dump_with_schema_search_path
      @configuration['schema_search_path'] = 'foo,bar'

      Kernel.expects(:system).with('pg_dump', '-s', '-x', '-O', '-f', @filename, '--schema=foo', '--schema=bar', 'my-app-db').returns(true)

      ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
    end

    def test_structure_dump_with_schema_search_path_and_dump_schemas_all
      @configuration['schema_search_path'] = 'foo,bar'

      Kernel.expects(:system).with("pg_dump", '-s', '-x', '-O', '-f', @filename,  'my-app-db').returns(true)

      with_dump_schemas(:all) do
        ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
      end
    end

    def test_structure_dump_with_dump_schemas_string
      Kernel.expects(:system).with("pg_dump", '-s', '-x', '-O', '-f', @filename, '--schema=foo', '--schema=bar', "my-app-db").returns(true)

      with_dump_schemas('foo,bar') do
        ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
      end
    end

    private

    def with_dump_schemas(value, &block)
      old_dump_schemas = ActiveRecord::Base.dump_schemas
      ActiveRecord::Base.dump_schemas = value
      yield
    ensure
      ActiveRecord::Base.dump_schemas = old_dump_schemas
    end
  end

  class PostgreSQLStructureLoadTest < ActiveRecord::TestCase
    def setup
      @connection    = stub
      @configuration = {
        'adapter'  => 'postgresql',
        'database' => 'my-app-db'
      }

      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
      Kernel.stubs(:system)
    end

    def test_structure_load
      filename = "awesome-file.sql"
      Kernel.expects(:system).with('psql', '-v', 'ON_ERROR_STOP=1', '-q', '-f', filename, @configuration['database']).returns(true)

      ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
    end

    def test_structure_load_accepts_path_with_spaces
      filename = "awesome file.sql"
      Kernel.expects(:system).with('psql', '-v', 'ON_ERROR_STOP=1', '-q', '-f', filename, @configuration['database']).returns(true)

      ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
    end
  end
end
end
