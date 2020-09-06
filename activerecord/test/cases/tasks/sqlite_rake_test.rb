# frozen_string_literal: true

require 'cases/helper'
require 'active_record/tasks/database_tasks'
require 'pathname'

if current_adapter?(:SQLite3Adapter)
  module ActiveRecord
    class SqliteDBCreateTest < ActiveRecord::TestCase
      def setup
        @database      = 'db_create.sqlite3'
        @configuration = {
          'adapter'  => 'sqlite3',
          'database' => @database
        }
        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_db_checks_database_exists
        ActiveRecord::Base.stub(:establish_connection, nil) do
          assert_called_with(File, :exist?, [@database], returns: false) do
            ActiveRecord::Tasks::DatabaseTasks.create @configuration, '/rails/root'
          end
        end
      end

      def test_when_db_created_successfully_outputs_info_to_stdout
        ActiveRecord::Base.stub(:establish_connection, nil) do
          ActiveRecord::Tasks::DatabaseTasks.create @configuration, '/rails/root'

          assert_equal "Created database '#{@database}'\n", $stdout.string
        end
      end

      def test_db_create_when_file_exists
        File.stub(:exist?, true) do
          ActiveRecord::Tasks::DatabaseTasks.create @configuration, '/rails/root'

          assert_equal "Database '#{@database}' already exists\n", $stderr.string
        end
      end

      def test_db_create_with_file_does_nothing
        File.stub(:exist?, true) do
          assert_not_called(ActiveRecord::Base, :establish_connection) do
            ActiveRecord::Tasks::DatabaseTasks.create @configuration, '/rails/root'
          end
        end
      end

      def test_db_create_establishes_a_connection
        calls = []
        ActiveRecord::Base.stub(:establish_connection, proc { |*args| calls << args }) do
          ActiveRecord::Tasks::DatabaseTasks.create @configuration, '/rails/root'
        end

        assert_equal [@configuration.symbolize_keys], calls.map { |c| c.first.configuration_hash }
      end

      def test_db_create_with_error_prints_message
        ActiveRecord::Base.stub(:establish_connection, proc { raise Exception }) do
          assert_raises(Exception) { ActiveRecord::Tasks::DatabaseTasks.create @configuration, '/rails/root' }
          assert_match "Couldn't create '#{@configuration['database']}' database. Please check your configuration.", $stderr.string
        end
      end
    end

    class SqliteDBDropTest < ActiveRecord::TestCase
      def setup
        @database      = 'db_create.sqlite3'
        @configuration = {
          'adapter'  => 'sqlite3',
          'database' => @database
        }
        @path = Class.new do
          def to_s; '/absolute/path' end
          def absolute?; true end
        end.new

        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_creates_path_from_database
        assert_called_with(Pathname, :new, [@database], returns: @path) do
          ActiveRecord::Tasks::DatabaseTasks.drop @configuration, '/rails/root'
        end
      end

      def test_removes_file_with_absolute_path
        Pathname.stub(:new, @path) do
          assert_called_with(FileUtils, :rm, ['/absolute/path']) do
            ActiveRecord::Tasks::DatabaseTasks.drop @configuration, '/rails/root'
          end
        end
      end

      def test_generates_absolute_path_with_given_root
        Pathname.stub(:new, @path) do
          @path.stub(:absolute?, false) do
            assert_called_with(File, :join, ['/rails/root', @path],
              returns: '/former/relative/path'
            ) do
              ActiveRecord::Tasks::DatabaseTasks.drop @configuration, '/rails/root'
            end
          end
        end
      end

      def test_removes_file_with_relative_path
        File.stub(:join, '/former/relative/path') do
          @path.stub(:absolute?, false) do
            assert_called_with(FileUtils, :rm, ['/former/relative/path']) do
              ActiveRecord::Tasks::DatabaseTasks.drop @configuration, '/rails/root'
            end
          end
        end
      end

      def test_when_db_dropped_successfully_outputs_info_to_stdout
        FileUtils.stub(:rm, nil) do
          ActiveRecord::Tasks::DatabaseTasks.drop @configuration, '/rails/root'

          assert_equal "Dropped database '#{@database}'\n", $stdout.string
        end
      end
    end

    class SqliteDBCharsetTest < ActiveRecord::TestCase
      def setup
        @database      = 'db_create.sqlite3'
        @connection    = Class.new { def encoding; end }.new
        @configuration = {
          'adapter'  => 'sqlite3',
          'database' => @database
        }
      end

      def test_db_retrieves_charset
        ActiveRecord::Base.stub(:connection, @connection) do
          assert_called(@connection, :encoding) do
            ActiveRecord::Tasks::DatabaseTasks.charset @configuration, '/rails/root'
          end
        end
      end
    end

    class SqliteDBCollationTest < ActiveRecord::TestCase
      def setup
        @database      = 'db_create.sqlite3'
        @configuration = {
          'adapter'  => 'sqlite3',
          'database' => @database
        }
      end

      def test_db_retrieves_collation
        assert_raise NoMethodError do
          ActiveRecord::Tasks::DatabaseTasks.collation @configuration, '/rails/root'
        end
      end
    end

    class SqliteStructureDumpTest < ActiveRecord::TestCase
      def setup
        @database      = 'db_create.sqlite3'
        @configuration = {
          'adapter'  => 'sqlite3',
          'database' => @database
        }

        `sqlite3 #{@database} 'CREATE TABLE bar(id INTEGER)'`
        `sqlite3 #{@database} 'CREATE TABLE foo(id INTEGER)'`
      end

      def test_structure_dump
        dbfile   = @database
        filename = 'awesome-file.sql'

        ActiveRecord::Tasks::DatabaseTasks.structure_dump @configuration, filename, '/rails/root'
        assert File.exist?(dbfile)
        assert File.exist?(filename)
        assert_match(/CREATE TABLE foo/, File.read(filename))
        assert_match(/CREATE TABLE bar/, File.read(filename))
      ensure
        FileUtils.rm_f(filename)
        FileUtils.rm_f(dbfile)
      end

      def test_structure_dump_with_ignore_tables
        dbfile   = @database
        filename = 'awesome-file.sql'
        assert_called(ActiveRecord::SchemaDumper, :ignore_tables, returns: ['foo']) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename, '/rails/root')
        end
        assert File.exist?(dbfile)
        assert File.exist?(filename)
        assert_match(/bar/, File.read(filename))
        assert_no_match(/foo/, File.read(filename))
      ensure
        FileUtils.rm_f(filename)
        FileUtils.rm_f(dbfile)
      end

      def test_structure_dump_execution_fails
        dbfile   = @database
        filename = 'awesome-file.sql'
        assert_called_with(
          Kernel,
          :system,
          ['sqlite3', '--noop', 'db_create.sqlite3', '.schema', out: 'awesome-file.sql'],
          returns: nil
        ) do
          e = assert_raise(RuntimeError) do
            with_structure_dump_flags(['--noop']) do
              quietly { ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename, '/rails/root') }
            end
          end
          assert_match('failed to execute:', e.message)
        end
      ensure
        FileUtils.rm_f(filename)
        FileUtils.rm_f(dbfile)
      end

      private
        def with_structure_dump_flags(flags)
          old = ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags
          ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = flags
          yield
        ensure
          ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = old
        end
    end

    class SqliteStructureLoadTest < ActiveRecord::TestCase
      def setup
        @database      = 'db_create.sqlite3'
        @configuration = {
          'adapter'  => 'sqlite3',
          'database' => @database
        }
      end

      def test_structure_load
        dbfile   = @database
        filename = 'awesome-file.sql'

        open(filename, 'w') { |f| f.puts("select datetime('now', 'localtime');") }
        ActiveRecord::Tasks::DatabaseTasks.structure_load @configuration, filename, '/rails/root'
        assert File.exist?(dbfile)
      ensure
        FileUtils.rm_f(filename)
        FileUtils.rm_f(dbfile)
      end
    end
  end
end
