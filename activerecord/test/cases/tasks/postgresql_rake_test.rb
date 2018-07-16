# frozen_string_literal: true

require "cases/helper"
require "active_record/tasks/database_tasks"

if current_adapter?(:PostgreSQLAdapter)
  module ActiveRecord
    class PostgreSQLDBCreateTest < ActiveRecord::TestCase
      def setup
        @connection    = Class.new { def create_database(*); end }.new
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }
        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_establishes_connection_to_postgresql_database
        ActiveRecord::Base.stubs(:establish_connection)
        ActiveRecord::Base.stub(:connection, @connection) do
          ActiveRecord::Base.expects(:establish_connection).with(
            "adapter"            => "postgresql",
            "database"           => "postgres",
            "schema_search_path" => "public"
          )
          ActiveRecord::Tasks::DatabaseTasks.create @configuration
        end
      end

      def test_creates_database_with_default_encoding
        with_stubbed_connection_establish_connection do
          @connection.expects(:create_database).
            with("my-app-db", @configuration.merge("encoding" => "utf8"))

          ActiveRecord::Tasks::DatabaseTasks.create @configuration
        end
      end

      def test_creates_database_with_given_encoding
        with_stubbed_connection_establish_connection do
          @connection.expects(:create_database).
            with("my-app-db", @configuration.merge("encoding" => "latin"))

          ActiveRecord::Tasks::DatabaseTasks.create @configuration.
            merge("encoding" => "latin")
        end
      end

      def test_creates_database_with_given_collation_and_ctype
        with_stubbed_connection_establish_connection do
          @connection.expects(:create_database).
            with("my-app-db", @configuration.merge("encoding" => "utf8", "collation" => "ja_JP.UTF8", "ctype" => "ja_JP.UTF8"))

          ActiveRecord::Tasks::DatabaseTasks.create @configuration.
            merge("collation" => "ja_JP.UTF8", "ctype" => "ja_JP.UTF8")
        end
      end

      def test_establishes_connection_to_new_database
        ActiveRecord::Base.stubs(:establish_connection)
        ActiveRecord::Base.stub(:connection, @connection) do
          ActiveRecord::Base.expects(:establish_connection).with(@configuration)

          ActiveRecord::Tasks::DatabaseTasks.create @configuration
        end
      end

      def test_db_create_with_error_prints_message
        ActiveRecord::Base.stub(:connection, @connection) do
          ActiveRecord::Base.stub(:establish_connection, -> * { raise Exception }) do
            assert_raises(Exception) { ActiveRecord::Tasks::DatabaseTasks.create @configuration }
            assert_match "Couldn't create database for #{@configuration.inspect}", $stderr.string
          end
        end
      end

      def test_when_database_created_successfully_outputs_info_to_stdout
        with_stubbed_connection_establish_connection do
          ActiveRecord::Tasks::DatabaseTasks.create @configuration

          assert_equal "Created database 'my-app-db'\n", $stdout.string
        end
      end

      def test_create_when_database_exists_outputs_info_to_stderr
        with_stubbed_connection_establish_connection do
          ActiveRecord::Base.connection.stub(
            :create_database,
            proc { raise ActiveRecord::Tasks::DatabaseAlreadyExists }
          ) do
            ActiveRecord::Tasks::DatabaseTasks.create @configuration

            assert_equal "Database 'my-app-db' already exists\n", $stderr.string
          end
        end
      end

      private

        def with_stubbed_connection_establish_connection
          ActiveRecord::Base.stub(:connection, @connection) do
            ActiveRecord::Base.stub(:establish_connection, nil) do
              yield
            end
          end
        end
    end

    class PostgreSQLDBDropTest < ActiveRecord::TestCase
      def setup
        @connection    = Class.new { def drop_database(*); end }.new
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }
        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_establishes_connection_to_postgresql_database
        ActiveRecord::Base.stub(:connection, @connection) do
          ActiveRecord::Base.expects(:establish_connection).with(
            "adapter"            => "postgresql",
            "database"           => "postgres",
            "schema_search_path" => "public"
          )
          ActiveRecord::Tasks::DatabaseTasks.drop @configuration
        end
      end

      def test_drops_database
        with_stubbed_connection_establish_connection do
          @connection.expects(:drop_database).with("my-app-db")

          ActiveRecord::Tasks::DatabaseTasks.drop @configuration
        end
      end

      def test_when_database_dropped_successfully_outputs_info_to_stdout
        with_stubbed_connection_establish_connection do
          ActiveRecord::Tasks::DatabaseTasks.drop @configuration

          assert_equal "Dropped database 'my-app-db'\n", $stdout.string
        end
      end

      private

        def with_stubbed_connection_establish_connection
          ActiveRecord::Base.stub(:connection, @connection) do
            ActiveRecord::Base.stub(:establish_connection, nil) do
              yield
            end
          end
        end
    end

    class PostgreSQLPurgeTest < ActiveRecord::TestCase
      def setup
        @connection = Class.new do
          def create_database(*); end
          def drop_database(*); end
        end.new
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }
      end

      def test_clears_active_connections
        with_stubbed_connection do
          ActiveRecord::Base.stub(:establish_connection, nil) do
            ActiveRecord::Base.expects(:clear_active_connections!)

            ActiveRecord::Tasks::DatabaseTasks.purge @configuration
          end
        end
      end

      def test_establishes_connection_to_postgresql_database
        ActiveRecord::Base.stubs(:establish_connection)
        with_stubbed_connection do
          ActiveRecord::Base.expects(:establish_connection).with(
            "adapter"            => "postgresql",
            "database"           => "postgres",
            "schema_search_path" => "public"
          )

          ActiveRecord::Tasks::DatabaseTasks.purge @configuration
        end
      end

      def test_drops_database
        with_stubbed_connection do
          ActiveRecord::Base.stub(:establish_connection, nil) do
            @connection.expects(:drop_database).with("my-app-db")

            ActiveRecord::Tasks::DatabaseTasks.purge @configuration
          end
        end
      end

      def test_creates_database
        with_stubbed_connection do
          ActiveRecord::Base.stub(:establish_connection, nil) do
            @connection.expects(:create_database).
              with("my-app-db", @configuration.merge("encoding" => "utf8"))

            ActiveRecord::Tasks::DatabaseTasks.purge @configuration
          end
        end
      end

      def test_establishes_connection
        ActiveRecord::Base.stubs(:establish_connection)
        with_stubbed_connection do
          ActiveRecord::Base.expects(:establish_connection).with(@configuration)

          ActiveRecord::Tasks::DatabaseTasks.purge @configuration
        end
      end

      private

        def with_stubbed_connection
          ActiveRecord::Base.stub(:connection, @connection) do
            yield
          end
        end
    end

    class PostgreSQLDBCharsetTest < ActiveRecord::TestCase
      def setup
        @connection    = Class.new { def create_database(*); end }.new
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }
      end

      def test_db_retrieves_charset
        ActiveRecord::Base.stub(:connection, @connection) do
          @connection.expects(:encoding)

          ActiveRecord::Tasks::DatabaseTasks.charset @configuration
        end
      end
    end

    class PostgreSQLDBCollationTest < ActiveRecord::TestCase
      def setup
        @connection    = Class.new { def create_database(*); end }.new
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }
      end

      def test_db_retrieves_collation
        ActiveRecord::Base.stub(:connection, @connection) do
          @connection.expects(:collation)

          ActiveRecord::Tasks::DatabaseTasks.collation @configuration
        end
      end
    end

    class PostgreSQLStructureDumpTest < ActiveRecord::TestCase
      def setup
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }
        @filename = "/tmp/awesome-file.sql"
        FileUtils.touch(@filename)
      end

      def teardown
        FileUtils.rm_f(@filename)
      end

      def test_structure_dump
        assert_called_with(
          Kernel,
          :system,
          ["pg_dump", "-s", "-x", "-O", "-f", @filename, "my-app-db"],
          returns: true
        ) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
        end
      end

      def test_structure_dump_header_comments_removed
        Kernel.stub(:system, true) do
          File.write(@filename, "-- header comment\n\n-- more header comment\n statement \n-- lower comment\n")
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)

          assert_equal [" statement \n", "-- lower comment\n"], File.readlines(@filename).first(2)
        end
      end

      def test_structure_dump_with_extra_flags
        expected_command = ["pg_dump", "-s", "-x", "-O", "-f", @filename, "--noop", "my-app-db"]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_dump_flags(["--noop"]) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
          end
        end
      end

      def test_structure_dump_with_ignore_tables
        assert_called(
          ActiveRecord::SchemaDumper,
          :ignore_tables,
          returns: ["foo", "bar"]
        ) do
          assert_called_with(
            Kernel,
            :system,
            ["pg_dump", "-s", "-x", "-O", "-f", @filename, "-T", "foo", "-T", "bar", "my-app-db"],
            returns: true
          ) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
          end
        end
      end

      def test_structure_dump_with_schema_search_path
        @configuration["schema_search_path"] = "foo,bar"

        assert_called_with(
          Kernel,
          :system,
          ["pg_dump", "-s", "-x", "-O", "-f", @filename, "--schema=foo", "--schema=bar", "my-app-db"],
          returns: true
        ) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
        end
      end

      def test_structure_dump_with_schema_search_path_and_dump_schemas_all
        @configuration["schema_search_path"] = "foo,bar"

        assert_called_with(
          Kernel,
          :system,
          ["pg_dump", "-s", "-x", "-O", "-f", @filename,  "my-app-db"],
          returns: true
        ) do
          with_dump_schemas(:all) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
          end
        end
      end

      def test_structure_dump_with_dump_schemas_string
        assert_called_with(
          Kernel,
          :system,
          ["pg_dump", "-s", "-x", "-O", "-f", @filename, "--schema=foo", "--schema=bar", "my-app-db"],
          returns: true
        ) do
          with_dump_schemas("foo,bar") do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
          end
        end
      end

      def test_structure_dump_execution_fails
        filename = "awesome-file.sql"
        assert_called_with(
          Kernel,
          :system,
          ["pg_dump", "-s", "-x", "-O", "-f", filename, "my-app-db"],
          returns: nil
        ) do
          e = assert_raise(RuntimeError) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
          end
          assert_match("failed to execute:", e.message)
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

        def with_structure_dump_flags(flags)
          old = ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags
          ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = flags
          yield
        ensure
          ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = old
        end
    end

    class PostgreSQLStructureLoadTest < ActiveRecord::TestCase
      def setup
        @configuration = {
          "adapter"  => "postgresql",
          "database" => "my-app-db"
        }
      end

      def test_structure_load
        filename = "awesome-file.sql"
        assert_called_with(
          Kernel,
          :system,
          ["psql", "-v", "ON_ERROR_STOP=1", "-q", "-f", filename, @configuration["database"]],
          returns: true
        ) do
          ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
        end
      end

      def test_structure_load_with_extra_flags
        filename = "awesome-file.sql"
        expected_command = ["psql", "-v", "ON_ERROR_STOP=1", "-q", "-f", filename, "--noop", @configuration["database"]]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_load_flags(["--noop"]) do
            ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
          end
        end
      end

      def test_structure_load_accepts_path_with_spaces
        filename = "awesome file.sql"
        assert_called_with(
          Kernel,
          :system,
          ["psql", "-v", "ON_ERROR_STOP=1", "-q", "-f", filename, @configuration["database"]],
          returns: true
        ) do
          ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
        end
      end

      private
        def with_structure_load_flags(flags)
          old = ActiveRecord::Tasks::DatabaseTasks.structure_load_flags
          ActiveRecord::Tasks::DatabaseTasks.structure_load_flags = flags
          yield
        ensure
          ActiveRecord::Tasks::DatabaseTasks.structure_load_flags = old
        end
    end
  end
end
