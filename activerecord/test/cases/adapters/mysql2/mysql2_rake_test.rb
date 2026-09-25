# frozen_string_literal: true

require "cases/helper"
require "active_record/tasks/database_tasks"

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

      mock = Minitest::Mock.new
      mock.expect(:call, nil, [adapter: "mysql2", database: nil])
      mock.expect(:call, nil, [db_config])

      ActiveRecord::Base.stub(:lease_connection, @connection) do
        ActiveRecord::Base.stub(:establish_connection, mock) do
          ActiveRecord::Tasks::DatabaseTasks.create(db_config)
        end
      end

      assert_mock(mock)
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

    def test_when_database_created_successfully_outputs_info_to_stdout
      with_stubbed_connection_establish_connection do
        ActiveRecord::Tasks::DatabaseTasks.create @configuration

        assert_equal "Created database 'my-app-db'\n", $stdout.string
      end
    end

    def test_create_when_database_exists_outputs_info_to_stderr
      with_stubbed_connection_establish_connection do
        ActiveRecord::Base.lease_connection.stub(
          :create_database,
          proc { raise ActiveRecord::DatabaseAlreadyExists }
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create @configuration

          assert_equal "Database 'my-app-db' already exists\n", $stderr.string
        end
      end
    end

    private
      def with_stubbed_connection_establish_connection(&block)
        ActiveRecord::Base.stub(:establish_connection, nil) do
          ActiveRecord::Base.stub(:lease_connection, @connection, &block)
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

      ActiveRecord::Base.stub(:lease_connection, @connection) do
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
      def with_stubbed_connection_establish_connection(&block)
        ActiveRecord::Base.stub(:establish_connection, nil) do
          ActiveRecord::Base.stub(:lease_connection, @connection, &block)
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

    def test_establishes_connection_without_database
      db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", @configuration)

      ActiveRecord::Base.stub(:lease_connection, @connection) do
        assert_called(ActiveRecord::Base, :establish_connection, times: 2) do
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
      def with_stubbed_connection_establish_connection(&block)
        ActiveRecord::Base.stub(:establish_connection, nil) do
          ActiveRecord::Base.stub(:lease_connection, @connection, &block)
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
      ActiveRecord::Base.stub(:lease_connection, @connection) do
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
      ActiveRecord::Base.stub(:lease_connection, @connection) do
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
        ["mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db", {}],
        returns: true
      ) do
        ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
      end
    end

    # Runs a real dump, since structure_load relies on it disabling foreign key checks.
    def test_structure_dump_output_disables_foreign_key_checks
      filename = "awesome-file.sql"
      config = ARTest.config["connections"]["mysql2"]["arunit"]

      ActiveRecord::Tasks::DatabaseTasks.structure_dump(config, filename)

      assert_match(/FOREIGN_KEY_CHECKS\s*=\s*0/, File.read(filename))
    ensure
      FileUtils.rm_f(filename)
    end

    def test_structure_dump_with_extra_flags
      filename = "awesome-file.sql"
      expected_command = ["mysqldump", "--noop", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db", {}]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_dump_flags(["--noop"]) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
        end
      end
    end

    def test_structure_dump_with_hash_extra_flags_for_a_different_driver
      filename = "awesome-file.sql"
      expected_command = ["mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db", {}]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_dump_flags({ postgresql: ["--noop"] }) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
        end
      end
    end

    def test_structure_dump_with_hash_extra_flags_for_the_correct_driver
      filename = "awesome-file.sql"
      expected_command = ["mysqldump", "--noop", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db", {}]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_dump_flags({ mysql2: ["--noop"] }) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
        end
      end
    end

    def test_structure_dump_with_ignore_tables
      filename = "awesome-file.sql"
      stub_dumped_database_connection(["foo", "bar", "prefix_foo", "ignored_foo"]) do
        ActiveRecord.stub(:schema_ignored_tables, [/^prefix_/, "ignored_foo"]) do
          assert_called_with(
            Kernel,
            :system,
            ["mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "--ignore-table=test-db.prefix_foo", "--ignore-table=test-db.ignored_foo", "test-db", {}],
            returns: true
          ) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
          end
        end
      end
    end

    def test_structure_dump_reads_ignored_tables_from_the_database_being_dumped
      filename = "awesome-file.sql"
      dumped_config = nil
      connection = Minitest::Mock.new
      connection.expect(:data_sources, ["prefix_in_dumped_database"])
      connection.expect(:disconnect!, nil)

      # A matching table in whichever database ActiveRecord::Base happens to be
      # connected to must not be what gets excluded.
      ActiveRecord::Base.lease_connection.stub(:data_sources, ["prefix_in_ambient_database"]) do
        ActiveRecord.stub(:schema_ignored_tables, [/^prefix_/]) do
          adapter_class.stub(:new, ->(config) { dumped_config = config; connection }) do
            assert_called_with(
              Kernel,
              :system,
              ["mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "--ignore-table=test-db.prefix_in_dumped_database", "test-db", {}],
              returns: true
            ) do
              ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
            end
          end
        end
      end

      assert_equal "test-db", dumped_config[:database]
      connection.verify
    end

    def test_warn_when_external_structure_dump_command_execution_fails
      filename = "awesome-file.sql"
      assert_called_with(
        Kernel,
        :system,
        ["mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db", {}],
        returns: false
      ) do
        e = assert_raise(RuntimeError) {
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, filename)
        }
        assert_match(/^failed to execute:\nmysqldump/, e.message)
      end
    end

    def test_structure_dump_command_failure_does_not_leak_the_password
      filename = "awesome-file.sql"
      assert_called_with(
        Kernel,
        :system,
        ["mysqldump", "--user=pat", "--password=wossname", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db", {}],
        returns: false
      ) do
        e = assert_raise(RuntimeError) {
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(
            @configuration.merge("username" => "pat", "password" => "wossname"),
            filename)
        }
        assert_no_match(/wossname/, e.message)
        assert_match("--password=[FILTERED]", e.message)
      end
    end

    def test_structure_dump_with_port_number
      filename = "awesome-file.sql"
      assert_called_with(
        Kernel,
        :system,
        ["mysqldump", "--port=10000", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db", {}],
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
        ["mysqldump", "--ssl-ca=ca.crt", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db", {}],
        returns: true
      ) do
        ActiveRecord::Tasks::DatabaseTasks.structure_dump(
          @configuration.merge("sslca" => "ca.crt"),
          filename)
      end
    end

    def test_structure_dump_ignores_ssl_options_mysql2_does_not_accept
      filename = "awesome-file.sql"
      assert_called_with(
        Kernel,
        :system,
        ["mysqldump", "--result-file", filename, "--no-data", "--routines", "--skip-comments", "test-db", {}],
        returns: true
      ) do
        ActiveRecord::Tasks::DatabaseTasks.structure_dump(
          @configuration.merge("ssl_ca" => "ca.crt"),
          filename)
      end
    end

    private
      def adapter_class
        ActiveRecord::Base.configurations.resolve(@configuration).adapter_class
      end

      def stub_dumped_database_connection(data_sources, &block)
        connection = Minitest::Mock.new
        connection.expect(:data_sources, data_sources)
        connection.expect(:disconnect!, nil)

        adapter_class.stub(:new, connection, &block)
        connection.verify
      end

      def with_structure_dump_flags(flags)
        old = ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags
        ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = flags
        yield
      ensure
        ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = old
      end
  end

  class MySQLStructureLoadTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    def setup
      @configuration = {
        "adapter"  => "mysql2",
        "database" => "test-db"
      }
    end

    def test_structure_load
      filename = "awesome-file.sql"
      expected_command = ["mysql", "--noop", "--database", "test-db", { in: filename }]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_load_flags(["--noop"]) do
          ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
        end
      end
    end

    def test_structure_load_reads_the_file_from_standard_input
      filename = "awesome-file.sql"
      config = ARTest.config["connections"]["mysql2"]["arunit"]
      File.write(filename, "CREATE TABLE structure_load_test (id int);\n")

      ActiveRecord::Tasks::DatabaseTasks.structure_load(config, filename)

      assert ActiveRecord::Base.lease_connection.table_exists?("structure_load_test")
    ensure
      ActiveRecord::Base.lease_connection.drop_table("structure_load_test", if_exists: true)
      FileUtils.rm_f(filename)
    end

    def test_structure_load_command_failure_names_the_file
      filename = "awesome-file.sql"
      expected_command = ["mysql", "--database", "test-db", { in: filename }]

      assert_called_with(Kernel, :system, expected_command, returns: false) do
        e = assert_raise(RuntimeError) {
          ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
        }
        assert_match("failed to execute:\nmysql --database test-db < awesome-file.sql", e.message)
      end
    end

    def test_structure_load_with_hash_extra_flags_for_a_different_driver
      filename = "awesome-file.sql"
      expected_command = ["mysql", "--database", "test-db", { in: filename }]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_load_flags({ postgresql: ["--noop"] }) do
          ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
        end
      end
    end

    def test_structure_load_with_hash_extra_flags_for_the_correct_driver
      filename = "awesome-file.sql"
      expected_command = ["mysql", "--noop", "--database", "test-db", { in: filename }]

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
