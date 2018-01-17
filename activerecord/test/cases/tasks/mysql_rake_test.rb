# frozen_string_literal: true

require "cases/helper"
require "active_record/tasks/database_tasks"

if current_adapter?(:Mysql2Adapter)
  module ActiveRecord
    class MysqlDBCreateTest < ActiveRecord::TestCase
      def setup
        @connection    = stub(create_database: true)
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-db"
        }

        ActiveRecord::Base.stubs(:connection).returns(@connection)
        ActiveRecord::Base.stubs(:establish_connection).returns(true)

        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_establishes_connection_without_database
        ActiveRecord::Base.expects(:establish_connection).
          with("adapter" => "mysql2", "database" => nil)

        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_creates_database_with_no_default_options
        @connection.expects(:create_database).
          with("my-app-db", {})

        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_creates_database_with_given_encoding
        @connection.expects(:create_database).
          with("my-app-db", charset: "latin1")

        ActiveRecord::Tasks::DatabaseTasks.create @configuration.merge("encoding" => "latin1")
      end

      def test_creates_database_with_given_collation
        @connection.expects(:create_database).
          with("my-app-db", collation: "latin1_swedish_ci")

        ActiveRecord::Tasks::DatabaseTasks.create @configuration.merge("collation" => "latin1_swedish_ci")
      end

      def test_establishes_connection_to_database
        ActiveRecord::Base.expects(:establish_connection).with(@configuration)

        ActiveRecord::Tasks::DatabaseTasks.create @configuration
      end

      def test_when_database_created_successfully_outputs_info_to_stdout
        ActiveRecord::Tasks::DatabaseTasks.create @configuration

        assert_equal "Created database 'my-app-db'\n", $stdout.string
      end

      def test_create_when_database_exists_outputs_info_to_stderr
        ActiveRecord::Base.connection.stubs(:create_database).raises(
          ActiveRecord::Tasks::DatabaseAlreadyExists
        )

        ActiveRecord::Tasks::DatabaseTasks.create @configuration

        assert_equal "Database 'my-app-db' already exists\n", $stderr.string
      end
    end

    class MysqlDBCreateWithInvalidPermissionsTest < ActiveRecord::TestCase
      def setup
        @connection    = stub("Connection", create_database: true)
        @error         = Mysql2::Error.new("Invalid permissions")
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-db",
          "username" => "pat",
          "password" => "wossname"
        }

        ActiveRecord::Base.stubs(:connection).returns(@connection)
        ActiveRecord::Base.stubs(:establish_connection).raises(@error)

        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_raises_error
        assert_raises(Mysql2::Error) do
          ActiveRecord::Tasks::DatabaseTasks.create @configuration
        end
      end
    end

    class MySQLDBDropTest < ActiveRecord::TestCase
      def setup
        @connection    = stub(drop_database: true)
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-db"
        }

        ActiveRecord::Base.stubs(:connection).returns(@connection)
        ActiveRecord::Base.stubs(:establish_connection).returns(true)

        $stdout, @original_stdout = StringIO.new, $stdout
        $stderr, @original_stderr = StringIO.new, $stderr
      end

      def teardown
        $stdout, $stderr = @original_stdout, @original_stderr
      end

      def test_establishes_connection_to_mysql_database
        ActiveRecord::Base.expects(:establish_connection).with @configuration

        ActiveRecord::Tasks::DatabaseTasks.drop @configuration
      end

      def test_drops_database
        @connection.expects(:drop_database).with("my-app-db")

        ActiveRecord::Tasks::DatabaseTasks.drop @configuration
      end

      def test_when_database_dropped_successfully_outputs_info_to_stdout
        ActiveRecord::Tasks::DatabaseTasks.drop @configuration

        assert_equal "Dropped database 'my-app-db'\n", $stdout.string
      end
    end

    class MySQLPurgeTest < ActiveRecord::TestCase
      def setup
        @connection    = stub(recreate_database: true)
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "test-db"
        }

        ActiveRecord::Base.stubs(:connection).returns(@connection)
        ActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_establishes_connection_to_the_appropriate_database
        ActiveRecord::Base.expects(:establish_connection).with(@configuration)

        ActiveRecord::Tasks::DatabaseTasks.purge @configuration
      end

      def test_recreates_database_with_no_default_options
        @connection.expects(:recreate_database).
          with("test-db", {})

        ActiveRecord::Tasks::DatabaseTasks.purge @configuration
      end

      def test_recreates_database_with_the_given_options
        @connection.expects(:recreate_database).
          with("test-db", charset: "latin", collation: "latin1_swedish_ci")

        ActiveRecord::Tasks::DatabaseTasks.purge @configuration.merge(
          "encoding" => "latin", "collation" => "latin1_swedish_ci")
      end
    end

    class MysqlDBCharsetTest < ActiveRecord::TestCase
      def setup
        @connection    = stub(create_database: true)
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-db"
        }

        ActiveRecord::Base.stubs(:connection).returns(@connection)
        ActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_db_retrieves_charset
        @connection.expects(:charset)
        ActiveRecord::Tasks::DatabaseTasks.charset @configuration
      end
    end

    class MysqlDBCollationTest < ActiveRecord::TestCase
      def setup
        @connection    = stub(create_database: true)
        @configuration = {
          "adapter"  => "mysql2",
          "database" => "my-app-db"
        }

        ActiveRecord::Base.stubs(:connection).returns(@connection)
        ActiveRecord::Base.stubs(:establish_connection).returns(true)
      end

      def test_db_retrieves_collation
        @connection.expects(:collation)
        ActiveRecord::Tasks::DatabaseTasks.collation @configuration
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
        Kernel.expects(:system).with("mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db").returns(true)

        ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
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

      def test_structure_dump_with_ignore_tables
        filename = "awesome-file.sql"
        ActiveRecord::SchemaDumper.expects(:ignore_tables).returns(["foo", "bar"])

        Kernel.expects(:system).with("mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "--ignore-table=test-db.foo", "--ignore-table=test-db.bar", "test-db").returns(true)

        ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
      end

      def test_warn_when_external_structure_dump_command_execution_fails
        filename = "awesome-file.sql"
        Kernel.expects(:system)
          .with("mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db")
          .returns(false)

        e = assert_raise(RuntimeError) {
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
        }
        assert_match(/^failed to execute: `mysqldump`$/, e.message)
      end

      def test_structure_dump_with_port_number
        filename = "awesome-file.sql"
        Kernel.expects(:system).with("mysqldump", "--port=10000", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db").returns(true)

        ActiveRecord::Tasks::DatabaseTasks.structure_dump(
          @configuration.merge("port" => 10000),
          filename)
      end

      def test_structure_dump_with_ssl
        filename = "awesome-file.sql"
        Kernel.expects(:system).with("mysqldump", "--ssl-ca=ca.crt", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db").returns(true)

        ActiveRecord::Tasks::DatabaseTasks.structure_dump(
          @configuration.merge("sslca" => "ca.crt"),
          filename)
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
