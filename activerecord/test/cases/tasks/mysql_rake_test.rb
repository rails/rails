# frozen_string_literal: true

require "cases/helper"
require "active_record/tasks/database_tasks"

if current_adapter?(:Mysql2Adapter)
  module ActiveRecord
    class MysqlDBCreateTest < ActiveRecord::TestCase
      def setup
        @connection = Class.new do
          def create_database(*); end
          def error_number(_); end
        end.new
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-db"
        }
        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_establishes_connection_without_database
        db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", @configuration)

        ActiveRecord::Base.stub(:connection, @connection) do
          assert_called_with(
            ActiveRecord::Base,
            :establish_connection,
            [
              [adapter: "mysql2", database: nil],
              [db_config]
            ]
          ) do
            ActiveRecord::Tasks::DatabaseTasks.create(db_config)
          end
        end
      end

      def test_creates_database_with_no_default_options
        with_stubbed_connection_establish_connection do
          assert_called_with(@connection, :create_database, ["my-app-db", {}]) do
            ActiveRecord::Tasks::DatabaseTasks.create @configuration
          end
        end
      end

      def test_creates_database_with_given_encoding
        with_stubbed_connection_establish_connection do
          assert_called_with(@connection, :create_database, ["my-app-db", charset: "latin1"]) do
            ActiveRecord::Tasks::DatabaseTasks.create @configuration.merge("encoding" => "latin1")
          end
        end
      end

      def test_creates_database_with_given_collation
        with_stubbed_connection_establish_connection do
          assert_called_with(
            @connection,
            :create_database,
            ["my-app-db", collation: "latin1_swedish_ci"]
          ) do
            ActiveRecord::Tasks::DatabaseTasks.create @configuration.merge("collation" => "latin1_swedish_ci")
          end
        end
      end

      def test_establishes_connection_to_database
        db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", @configuration)

        ActiveRecord::Base.stub(:connection, @connection) do
          assert_called_with(
            ActiveRecord::Base,
            :establish_connection,
            [
              [adapter: "mysql2", database: nil],
              [db_config]
            ]
          ) do
            ActiveRecord::Tasks::DatabaseTasks.create(db_config)
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
            proc { raise ActiveRecord::DatabaseAlreadyExists }
          ) do
            ActiveRecord::Tasks::DatabaseTasks.create @configuration

            assert_equal "Database 'my-app-db' already exists\n", $stderr.string
          end
        end
      end

      private
        def with_stubbed_connection_establish_connection
          ActiveRecord::Base.stub(:establish_connection, nil) do
            ActiveRecord::Base.stub(:connection, @connection) do
              yield
            end
          end
        end
    end

    class MysqlDBCreateWithInvalidPermissionsTest < ActiveRecord::TestCase
      def setup
        @error         = Mysql2::Error.new("Invalid permissions")
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-db",
          "username" => "pat",
          "password" => "wossname"
        }
        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_raises_error
        ActiveRecord::Base.stub(:establish_connection, -> * { raise @error }) do
          assert_raises(Mysql2::Error, "Invalid permissions") do
            ActiveRecord::Tasks::DatabaseTasks.create @configuration
          end
        end
      end
    end

    class MySQLDBDropTest < ActiveRecord::TestCase
      def setup
        @connection    = Class.new { def drop_database(name); end }.new
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-db"
        }
        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_establishes_connection_to_mysql_database
        db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", @configuration)

        ActiveRecord::Base.stub(:connection, @connection) do
          assert_called_with(
            ActiveRecord::Base,
            :establish_connection,
            [db_config]
          ) do
            ActiveRecord::Tasks::DatabaseTasks.drop(db_config)
          end
        end
      end

      def test_drops_database
        with_stubbed_connection_establish_connection do
          assert_called_with(@connection, :drop_database, ["my-app-db"]) do
            ActiveRecord::Tasks::DatabaseTasks.drop @configuration
          end
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
          ActiveRecord::Base.stub(:establish_connection, nil) do
            ActiveRecord::Base.stub(:connection, @connection) do
              yield
            end
          end
        end
    end

    class MySQLPurgeTest < ActiveRecord::TestCase
      def setup
        @connection    = Class.new { def recreate_database(*); end }.new
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "test-db"
        }
      end

      def test_establishes_connection_to_the_appropriate_database
        db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", @configuration)

        ActiveRecord::Base.stub(:connection, @connection) do
          assert_called_with(
            ActiveRecord::Base,
            :establish_connection,
            [db_config]
          ) do
            ActiveRecord::Tasks::DatabaseTasks.purge(db_config)
          end
        end
      end

      def test_recreates_database_with_no_default_options
        with_stubbed_connection_establish_connection do
          assert_called_with(@connection, :recreate_database, ["test-db", {}]) do
            ActiveRecord::Tasks::DatabaseTasks.purge @configuration
          end
        end
      end

      def test_recreates_database_with_the_given_options
        with_stubbed_connection_establish_connection do
          assert_called_with(
            @connection,
            :recreate_database,
            ["test-db", charset: "latin", collation: "latin1_swedish_ci"]
          ) do
            ActiveRecord::Tasks::DatabaseTasks.purge @configuration.merge(
              "encoding" => "latin", "collation" => "latin1_swedish_ci")
          end
        end
      end

      private
        def with_stubbed_connection_establish_connection
          ActiveRecord::Base.stub(:establish_connection, nil) do
            ActiveRecord::Base.stub(:connection, @connection) do
              yield
            end
          end
        end
    end

    class MysqlDBCharsetTest < ActiveRecord::TestCase
      def setup
        @connection    = Class.new { def charset; end }.new
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-db"
        }
      end

      def test_db_retrieves_charset
        ActiveRecord::Base.stub(:connection, @connection) do
          assert_called(@connection, :charset) do
            ActiveRecord::Tasks::DatabaseTasks.charset @configuration
          end
        end
      end
    end

    class MysqlDBCollationTest < ActiveRecord::TestCase
      def setup
        @connection    = Class.new { def collation; end }.new
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-db"
        }
      end

      def test_db_retrieves_collation
        ActiveRecord::Base.stub(:connection, @connection) do
          assert_called(@connection, :collation) do
            ActiveRecord::Tasks::DatabaseTasks.collation @configuration
          end
        end
      end
    end

    class MySQLStructureDumpTest < ActiveRecord::TestCase
      def setup
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "test-db"
        }
      end

      def test_structure_dump
        filename = "awesome-file.sql"
        assert_called_with(
          Kernel,
          :system,
          ["mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db"],
          returns: true
        ) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
        end
      end

      def test_structure_dump_with_extra_flags
        filename = "awesome-file.sql"
        expected_command = ["mysqldump", "--noop", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db"]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_dump_flags(["--noop"]) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
          end
        end
      end

      def test_structure_dump_with_hash_extra_flags_for_a_different_driver
        filename = "awesome-file.sql"
        expected_command = ["mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db"]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_dump_flags({ postgresql: ["--noop"] }) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
          end
        end
      end

      def test_structure_dump_with_hash_extra_flags_for_the_correct_driver
        filename = "awesome-file.sql"
        expected_command = ["mysqldump", "--noop", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db"]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_dump_flags({ mysql2: ["--noop"] }) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
          end
        end
      end

      def test_structure_dump_with_ignore_tables
        filename = "awesome-file.sql"
        ActiveRecord::SchemaDumper.stub(:ignore_tables, ["foo", "bar"]) do
          assert_called_with(
            Kernel,
            :system,
            ["mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "--ignore-table=test-db.foo", "--ignore-table=test-db.bar", "test-db"],
            returns: true
          ) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
          end
        end
      end

      def test_warn_when_external_structure_dump_command_execution_fails
        filename = "awesome-file.sql"
        assert_called_with(
          Kernel,
          :system,
          ["mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db"],
          returns: false
        ) do
          e = assert_raise(RuntimeError) {
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
          }
          assert_match(/^failed to execute: `mysqldump`$/, e.message)
        end
      end

      def test_structure_dump_with_port_number
        filename = "awesome-file.sql"
        assert_called_with(
          Kernel,
          :system,
          ["mysqldump", "--port=10000", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db"],
          returns: true
        ) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(
            @configuration.merge("port" => 10000),
            filename)
        end
      end

      def test_structure_dump_with_ssl
        filename = "awesome-file.sql"
        assert_called_with(
          Kernel,
          :system,
          ["mysqldump", "--ssl-ca=ca.crt", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db"],
          returns: true
        ) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(
              @configuration.merge("sslca" => "ca.crt"),
              filename)
          end
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

    class MySQLStructureLoadTest < ActiveRecord::TestCase
      def setup
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "test-db"
        }
      end

      def test_structure_load
        filename = "awesome-file.sql"
        expected_command = ["mysql", "--noop", "--execute", %{SET FOREIGN_KEY_CHECKS = 0; SOURCE #{filename}; SET FOREIGN_KEY_CHECKS = 1}, "--database", "test-db"]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_load_flags(["--noop"]) do
            ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
          end
        end
      end

      def test_structure_load_with_hash_extra_flags_for_a_different_driver
        filename = "awesome-file.sql"
        expected_command = ["mysql", "--execute", %{SET FOREIGN_KEY_CHECKS = 0; SOURCE #{filename}; SET FOREIGN_KEY_CHECKS = 1}, "--database", "test-db"]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_load_flags({ postgresql: ["--noop"] }) do
            ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
          end
        end
      end

      def test_structure_load_with_hash_extra_flags_for_the_correct_driver
        filename = "awesome-file.sql"
        expected_command = ["mysql", "--noop", "--execute", %{SET FOREIGN_KEY_CHECKS = 0; SOURCE #{filename}; SET FOREIGN_KEY_CHECKS = 1}, "--database", "test-db"]

        assert_called_with(Kernel, :system, expected_command, returns: true) do
          with_structure_load_flags({ mysql2: ["--noop"] }) do
            ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
          end
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
