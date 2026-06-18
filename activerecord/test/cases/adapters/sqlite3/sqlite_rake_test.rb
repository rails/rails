# frozen_string_literal: true

require "cases/helper"
require "active_record/tasks/database_tasks"
require "pathname"

module ActiveRecord
  class SqliteDBCreateTest < ActiveRecord::TestCase
    def setup
      @database      = "db_create.sqlite3"
      @configuration = {
        "adapter"  => "sqlite3",
        "database" => @database
      }
      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
    end

    def test_db_checks_database_exists
      ActiveRecord::Base.stub(:establish_connection, nil) do
        assert_called_with(ConnectionAdapters::SQLite3Adapter, :resolve_path, [@database], returns: @database_root) do
          assert_called_with(File, :exist?, [@database_root], returns: false) do
            ActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root"
          end
        end
      end
    end

    def test_when_db_created_successfully_outputs_info_to_stdout
      ActiveRecord::Base.stub(:establish_connection, nil) do
        ActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root"

        assert_equal "Created database '#{@database}'\n", $stdout.string
      end
    end

    def test_db_create_when_file_exists
      File.stub(:exist?, true) do
        ActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root"

        assert_equal "Database '#{@database}' already exists\n", $stderr.string
      end
    end

    def test_db_create_with_file_does_nothing
      File.stub(:exist?, true) do
        assert_not_called(ActiveRecord::Base, :establish_connection) do
          ActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root"
        end
      end
    end

    def test_db_create_establishes_a_connection
      calls = []
      ActiveRecord::Base.stub(:establish_connection, proc { |*args| calls << args }) do
        ActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root"
      end

      assert_equal [@configuration.symbolize_keys], calls.map { |c| c.first.configuration_hash }
    end

    def test_db_create_with_error_prints_message
      ActiveRecord::Base.stub(:establish_connection, proc { raise Exception }) do
        assert_raises(Exception) { ActiveRecord::Tasks::DatabaseTasks.create @configuration, "/rails/root" }
        assert_match "Couldn't create '#{@configuration['database']}' database. Please check your configuration.", $stderr.string
      end
    end
  end

  class SqliteDBDropTest < ActiveRecord::TestCase
    def setup
      @root          = "/rails/root"
      @database      = "db_create.sqlite3"
      @database_root = File.join(@root, @database)
      @configuration = {
        "adapter"  => "sqlite3",
        "database" => @database
      }
      @configuration_root = {
        "adapter"  => "sqlite3",
        "database" => @database_root
      }

      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
    end

    def test_removes_fully_resolved_db_path
      assert_called_with(ConnectionAdapters::SQLite3Adapter, :resolve_path, [@database], root: "/rails/root", returns: @database_root) do
        assert_called_with(FileUtils, :rm, [@database_root]) do
          assert_called_with(FileUtils, :rm_f, [["#{@database_root}-shm", "#{@database_root}-wal"]]) do
            ActiveRecord::Tasks::DatabaseTasks.drop @configuration, @root
          end
        end
      end
    end

    def test_when_db_dropped_successfully_outputs_info_to_stdout
      FileUtils.stub(:rm, nil) do
        ActiveRecord::Tasks::DatabaseTasks.drop @configuration, @root

        assert_equal "Dropped database '#{@database}'\n", $stdout.string
      end
    end
  end

  class SqliteDBDropAndRecreateTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    unless in_memory_db?
      def test_drop_then_create_persists_to_the_recreated_database_file
        dir = Dir.mktmpdir
        file = File.join(dir, "phantom.sqlite3")
        db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
          "arunit", "primary", adapter: "sqlite3", database: file
        )

        ActiveRecord::Base.establish_connection(db_config)
        ActiveRecord::Base.lease_connection.create_table(:dogs)

        quietly do
          ActiveRecord::Tasks::DatabaseTasks.drop(db_config, dir)
          ActiveRecord::Tasks::DatabaseTasks.create(db_config, dir)
        end

        assert File.exist?(file), "expected db:create to recreate the database file on disk"

        ActiveRecord::Base.lease_connection.create_table(:cats)
        ActiveRecord::Base.connection_handler.clear_all_connections!
        ActiveRecord::Base.establish_connection(db_config)

        assert ActiveRecord::Base.lease_connection.table_exists?(:cats),
          "expected the schema created after db:create to persist to the new file"
      ensure
        ActiveRecord::Base.connection_handler.clear_all_connections!
        FileUtils.remove_entry(dir) if dir
        ActiveRecord::Base.establish_connection :arunit
      end

      def test_drop_does_not_recreate_a_missing_database
        dir = Dir.mktmpdir
        file = File.join(dir, "missing.sqlite3")
        db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
          "arunit", "primary", adapter: "sqlite3", database: file
        )

        ActiveRecord::Base.establish_connection(db_config)
        assert_not File.exist?(file), "test setup: the database file must not exist yet"

        output = capture(:stderr) do
          ActiveRecord::Tasks::DatabaseTasks.drop(db_config, dir)
        end

        assert_not File.exist?(file), "drop must not create the missing database file"
        assert_match "Database '#{file}' does not exist", output
      ensure
        FileUtils.remove_entry(dir) if dir
        ActiveRecord::Base.establish_connection :arunit
      end

      def test_drop_does_not_disconnect_a_different_database
        dir = Dir.mktmpdir
        dropped = File.join(dir, "dropped.sqlite3")
        live = File.join(dir, "live.sqlite3")
        live_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
          "arunit", "primary", adapter: "sqlite3", database: live
        )
        dropped_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
          "arunit", "primary", adapter: "sqlite3", database: dropped
        )

        ActiveRecord::Base.establish_connection(live_config)
        ActiveRecord::Base.lease_connection.create_table(:bees)
        assert_predicate ActiveRecord::Base.lease_connection, :active?

        File.write(dropped, "")
        quietly { ActiveRecord::Tasks::DatabaseTasks.drop(dropped_config, dir) }

        assert_not File.exist?(dropped), "expected the dropped database file to be removed"
        assert_predicate ActiveRecord::Base.lease_connection, :active?,
          "dropping a different database must not disconnect the active connection"
      ensure
        ActiveRecord::Base.connection_handler.clear_all_connections!
        FileUtils.remove_entry(dir) if dir
        ActiveRecord::Base.establish_connection :arunit
      end
    end
  end

  class SqliteDBCharsetTest < ActiveRecord::TestCase
    def setup
      @database      = "db_create.sqlite3"
      @connection    = Class.new { def encoding; end }.new
      @configuration = {
        "adapter"  => "sqlite3",
        "database" => @database
      }
    end

    def test_db_retrieves_charset
      ActiveRecord::Base.stub(:lease_connection, @connection) do
        assert_called(@connection, :encoding) do
          ActiveRecord::Tasks::DatabaseTasks.charset @configuration, "/rails/root"
        end
      end
    end
  end

  class SqliteDBCollationTest < ActiveRecord::TestCase
    def setup
      @database      = "db_create.sqlite3"
      @configuration = {
        "adapter"  => "sqlite3",
        "database" => @database
      }
    end

    def test_db_retrieves_collation
      assert_raise NoMethodError do
        ActiveRecord::Tasks::DatabaseTasks.collation @configuration, "/rails/root"
      end
    end
  end

  class SqliteStructureDumpTest < ActiveRecord::TestCase
    def setup
      @database      = "db_create.sqlite3"
      @configuration = {
        "adapter"  => "sqlite3",
        "database" => @database
      }

      `sqlite3 #{@database} 'CREATE TABLE bar(id INTEGER)'`
      `sqlite3 #{@database} 'CREATE TABLE foo(id INTEGER)'`
    end

    def test_structure_dump
      dbfile   = @database
      filename = "awesome-file.sql"

      ActiveRecord::Tasks::DatabaseTasks.structure_dump @configuration, filename, "/rails/root"
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
      filename = "awesome-file.sql"
      ActiveRecord::Base.lease_connection.stub(:data_sources, ["foo", "bar", "prefix_foo", "ignored_foo"]) do
        ActiveRecord::SchemaDumper.stub(:ignore_tables, [/^prefix_/, "ignored_foo"]) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename, "/rails/root")
        end
      end
      assert File.exist?(dbfile)
      assert File.exist?(filename)
      contents = File.read(filename)
      assert_match(/bar/, contents)
      assert_no_match(/prefix_foo/, contents)
      assert_no_match(/ignored_foo/, contents)
    ensure
      FileUtils.rm_f(filename)
      FileUtils.rm_f(dbfile)
    end

    def test_structure_dump_execution_fails
      dbfile   = @database
      filename = "awesome-file.sql"
      assert_called_with(
        Kernel,
        :system,
        ["sqlite3", "--noop", "db_create.sqlite3", ".schema --nosys", { out: "awesome-file.sql" }],
        returns: nil,
      ) do
        e = assert_raise(RuntimeError) do
          with_structure_dump_flags(["--noop"]) do
            quietly { ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename, "/rails/root") }
          end
        end
        assert_match("failed to execute:", e.message)
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
      @database      = "db_create.sqlite3"
      @configuration = {
        "adapter"  => "sqlite3",
        "database" => @database
      }
    end

    def test_structure_load
      dbfile   = @database
      filename = "awesome-file.sql"

      open(filename, "w") { |f| f.puts("select datetime('now', 'localtime');") }
      quietly { ActiveRecord::Tasks::DatabaseTasks.structure_load @configuration, filename, "/rails/root" }
      assert File.exist?(dbfile)
    ensure
      FileUtils.rm_f(filename)
      FileUtils.rm_f(dbfile)
    end
  end
end
