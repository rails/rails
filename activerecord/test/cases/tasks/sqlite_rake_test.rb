require 'cases/helper'
require 'pathname'

module ActiveRecord
  class SqliteDBCreateTest < ActiveRecord::TestCase
    def setup
      @database      = 'db_create.sqlite3'
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

      ActiveRecord::Tasks::DatabaseTasks.create @configuration, '/rails/root'
    end

    def test_db_create_when_file_exists
      File.stubs(:exist?).returns(true)

      $stderr.expects(:puts).with("#{@database} already exists")

      ActiveRecord::Tasks::DatabaseTasks.create @configuration, '/rails/root'
    end

    def test_db_create_with_file_does_nothing
      File.stubs(:exist?).returns(true)
      $stderr.stubs(:puts).returns(nil)

      ActiveRecord::Base.expects(:establish_connection).never

      ActiveRecord::Tasks::DatabaseTasks.create @configuration, '/rails/root'
    end

    def test_db_create_establishes_a_connection
      ActiveRecord::Base.expects(:establish_connection).with(@configuration)

      ActiveRecord::Tasks::DatabaseTasks.create @configuration, '/rails/root'
    end

    def test_db_create_with_error_prints_message
      ActiveRecord::Base.stubs(:establish_connection).raises(Exception)

      $stderr.stubs(:puts).returns(true)
      $stderr.expects(:puts).
        with("Couldn't create database for #{@configuration.inspect}")

      ActiveRecord::Tasks::DatabaseTasks.create @configuration, '/rails/root'
    end
  end

  class SqliteDBDropTest < ActiveRecord::TestCase
    def setup
      config = { 'adapter'  => 'sqlite3' }
      @absolute_params = [config.merge('database' => '/path/db_create.sqlite3'), '/rails/root']
      @relative_params = [config.merge('database' => 'db_create.sqlite3'), '/rails/root']
    end

    def test_calls_proper_drop_method
      tasks = stub :tasks
      ActiveRecord::Tasks::SQLiteDatabaseTasks.expects(:new).with(*@relative_params).returns(tasks)
      tasks.expects(:drop)

      ActiveRecord::Tasks::DatabaseTasks.drop *@relative_params
    end

    def test_generates_absolute_path_with_given_root
      Pathname.any_instance.stubs(:delete)
      tasks = ActiveRecord::Tasks::SQLiteDatabaseTasks.new(*@relative_params)
      tasks.drop
      assert_equal tasks.send(:dbfile_path).to_s, '/rails/root/db_create.sqlite3'
    end

    def test_removes_file_by_relative_path
      dbfile_path = stub :dbfile_path
      tasks = ActiveRecord::Tasks::SQLiteDatabaseTasks.new(*@relative_params)
      tasks.stubs(:dbfile_path).returns(dbfile_path)
      dbfile_path.expects(:exist?).returns(true)
      dbfile_path.expects(:delete)
      tasks.drop
    end

    def test_leaves_absolute_path_unchanged
      Pathname.any_instance.stubs(:delete)
      tasks = ActiveRecord::Tasks::SQLiteDatabaseTasks.new(*@absolute_params)
      tasks.drop
      assert_equal tasks.send(:dbfile_path).to_s, '/path/db_create.sqlite3'
    end

    def test_removes_file_by_absolute_path
      dbfile_path = stub :dbfile_path
      tasks = ActiveRecord::Tasks::SQLiteDatabaseTasks.new(*@absolute_params)
      tasks.stubs(:dbfile_path).returns(dbfile_path)
      dbfile_path.expects(:exist?).returns(true)
      dbfile_path.expects(:delete)
      tasks.drop
    end
  end

  class SqliteDBCharsetTest < ActiveRecord::TestCase
    def setup
      @database      = 'db_create.sqlite3'
      @connection    = stub :connection
      @configuration = {
        'adapter'  => 'sqlite3',
        'database' => @database
      }

      File.stubs(:exist?).returns(false)
      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_db_retrieves_charset
      @connection.expects(:encoding)
      ActiveRecord::Tasks::DatabaseTasks.charset @configuration, '/rails/root'
    end
  end

  class SqliteDBCollationTest < ActiveRecord::TestCase
    def setup
      @database      = 'db_create.sqlite3'
      @connection    = stub :connection
      @configuration = {
        'adapter'  => 'sqlite3',
        'database' => @database
      }

      File.stubs(:exist?).returns(false)
      ActiveRecord::Base.stubs(:connection).returns(@connection)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_db_retrieves_collation
      assert_raise NoMethodError do
        ActiveRecord::Tasks::DatabaseTasks.collation @configuration, '/rails/root'
      end
    end
  end

  class SqliteStructureDumpTest < ActiveRecord::TestCase
    def setup
      @filename = "awesome-file.sql"
      @config = { 'adapter'  => 'sqlite3' }
    end

    def test_dumps_structure_by_db_relative_path
      ActiveRecord::Tasks::SQLiteDatabaseTasks.any_instance.expects(:`).
        with(%Q(sqlite3 "/rails/root/db_create.sqlite3" .schema > "#@filename"))

      relative_params = [config.merge('database' => 'db_create.sqlite3'), @filename, '/rails/root']
      ActiveRecord::Tasks::DatabaseTasks.structure_dump *relative_params
    end

    def test_dumps_structure_by_db_absolute_path
      ActiveRecord::Tasks::SQLiteDatabaseTasks.any_instance.expects(:`).
        with(%Q(sqlite3 "/path/db_create.sqlite3" .schema > "#@filename"))

      absolute_params = [config.merge('database' => '/path/db_create.sqlite3'), @filename, '/rails/root']
      ActiveRecord::Tasks::DatabaseTasks.structure_dump *absolute_params
    end
  end

  class SqliteStructureLoadTest < ActiveRecord::TestCase
    def setup
      @filename = "awesome-file.sql"
      @config = { 'adapter'  => 'sqlite3' }
    end

    def test_dumps_structure_by_db_relative_path
      ActiveRecord::Tasks::SQLiteDatabaseTasks.any_instance.expects(:`).
        with(%Q(sqlite3 "/rails/root/db_create.sqlite3" < "#@filename"))

      relative_params = [config.merge('database' => 'db_create.sqlite3'), @filename, '/rails/root']
      ActiveRecord::Tasks::DatabaseTasks.structure_load *relative_params
    end

    def test_dumps_structure_by_db_absolute_path
      ActiveRecord::Tasks::SQLiteDatabaseTasks.any_instance.expects(:`).
        with(%Q(sqlite3 "/path/db_create.sqlite3" < "#@filename"))

      absolute_params = [config.merge('database' => '/path/db_create.sqlite3'), @filename, '/rails/root']
      ActiveRecord::Tasks::DatabaseTasks.structure_load *absolute_params
    end
  end
end
