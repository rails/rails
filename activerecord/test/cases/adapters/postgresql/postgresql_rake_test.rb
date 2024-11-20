# frozen_string_literal: true

require "cases/helper"
require "active_record/tasks/database_tasks"

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
      db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", @configuration)

      mock = Minitest::Mock.new
      mock.expect(:call, nil, [{ adapter: "postgresql", database: "postgres", schema_search_path: "public" }])
      mock.expect(:call, nil, [db_config])

      ActiveRecord::Base.stub(:lease_connection, @connection) do
        ActiveRecord::Base.stub(:establish_connection, mock) do
          ActiveRecord::Tasks::DatabaseTasks.create(db_config)
        end
      end

      assert_mock(mock)
    end

    def test_creates_database_with_default_encoding
      with_stubbed_connection_establish_connection do
        assert_called_with(
          @connection,
          :create_database,
          ["my-app-db", @configuration.symbolize_keys.merge(encoding: "utf8")]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create @configuration
        end
      end
    end

    def test_creates_database_with_given_encoding
      with_stubbed_connection_establish_connection do
        assert_called_with(
          @connection,
          :create_database,
          ["my-app-db", @configuration.symbolize_keys.merge(encoding: "latin")]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create @configuration.
            merge("encoding" => "latin")
        end
      end
    end

    def test_creates_database_with_given_collation_and_ctype
      with_stubbed_connection_establish_connection do
        assert_called_with(
          @connection,
          :create_database,
          [
            "my-app-db",
            @configuration.symbolize_keys.merge(
              encoding: "utf8",
              collation: "ja_JP.UTF8",
              ctype: "ja_JP.UTF8"
            )
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create @configuration.
            merge("collation" => "ja_JP.UTF8", "ctype" => "ja_JP.UTF8")
        end
      end
    end

    def test_establishes_connection_to_new_database
      db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", @configuration)

      mock = Minitest::Mock.new
      mock.expect(:call, nil, [{ adapter: "postgresql", database: "postgres", schema_search_path: "public" }])
      mock.expect(:call, nil, [db_config])

      ActiveRecord::Base.stub(:lease_connection, @connection) do
        ActiveRecord::Base.stub(:establish_connection, mock) do
          ActiveRecord::Tasks::DatabaseTasks.create(db_config)
        end
      end

      assert_mock(mock)
    end

    def test_db_create_with_error_prints_message
      ActiveRecord::Base.stub(:lease_connection, @connection) do
        ActiveRecord::Base.stub(:establish_connection, -> * { raise Exception }) do
          assert_raises(Exception) { ActiveRecord::Tasks::DatabaseTasks.create @configuration }
          assert_match "Couldn't create '#{@configuration['database']}' database. Please check your configuration.", $stderr.string
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
        ActiveRecord::Base.stub(:lease_connection, @connection) do
          ActiveRecord::Base.stub(:establish_connection, nil, &block)
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
      ActiveRecord::Base.stub(:lease_connection, @connection) do
        assert_called_with(
          ActiveRecord::Base,
          :establish_connection,
          [
            adapter: "postgresql",
            database: "postgres",
            schema_search_path: "public"
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.drop @configuration
        end
      end
    end

    def test_drops_database
      with_stubbed_connection_establish_connection do
        assert_called_with(
          @connection,
          :drop_database,
          ["my-app-db"]
        ) do
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
        ActiveRecord::Base.stub(:lease_connection, @connection) do
          ActiveRecord::Base.stub(:establish_connection, nil, &block)
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
        ActiveRecord::Base.connection_handler.stub(:establish_connection, nil) do
          assert_called(ActiveRecord::Base.connection_handler, :clear_active_connections!) do
            ActiveRecord::Tasks::DatabaseTasks.purge @configuration
          end
        end
      end
    end

    def test_establishes_connection_to_postgresql_database
      db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", @configuration)

      mock = Minitest::Mock.new
      mock.expect(:call, nil, [{ adapter: "postgresql", database: "postgres", schema_search_path: "public" }])
      mock.expect(:call, nil, [db_config])

      with_stubbed_connection do
        ActiveRecord::Base.stub(:establish_connection, mock) do
          ActiveRecord::Tasks::DatabaseTasks.purge(db_config)
        end
      end

      assert_mock(mock)
    end

    def test_drops_database
      with_stubbed_connection do
        ActiveRecord::Base.stub(:establish_connection, nil) do
          assert_called_with(@connection, :drop_database, ["my-app-db"]) do
            ActiveRecord::Tasks::DatabaseTasks.purge @configuration
          end
        end
      end
    end

    def test_creates_database
      with_stubbed_connection do
        ActiveRecord::Base.stub(:establish_connection, nil) do
          assert_called_with(
            @connection,
            :create_database,
            ["my-app-db", @configuration.symbolize_keys.merge(encoding: "utf8")]
          ) do
            ActiveRecord::Tasks::DatabaseTasks.purge @configuration
          end
        end
      end
    end

    def test_establishes_connection
      db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", @configuration)

      mock = Minitest::Mock.new
      mock.expect(:call, nil, [{ adapter: "postgresql", database: "postgres", schema_search_path: "public" }])
      mock.expect(:call, nil, [db_config])

      with_stubbed_connection do
        ActiveRecord::Base.stub(:establish_connection, mock) do
          ActiveRecord::Tasks::DatabaseTasks.purge(db_config)
        end
      end

      assert_mock(mock)
    end

    private
      def with_stubbed_connection(&block)
        ActiveRecord::Base.stub(:lease_connection, @connection, &block)
      end
  end

  class PostgreSQLDBCharsetTest < ActiveRecord::TestCase
    def setup
      @connection = Class.new do
        def create_database(*); end
        def encoding; end
      end.new
      @configuration = {
        "adapter"  => "postgresql",
        "database" => "my-app-db"
      }
    end

    def test_db_retrieves_charset
      ActiveRecord::Base.stub(:lease_connection, @connection) do
        assert_called(@connection, :encoding) do
          ActiveRecord::Tasks::DatabaseTasks.charset @configuration
        end
      end
    end
  end

  class PostgreSQLDBCollationTest < ActiveRecord::TestCase
    def setup
      @connection    = Class.new { def collation; end }.new
      @configuration = {
        "adapter"  => "postgresql",
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

    # This test actually runs a dump so we can ensure all the arguments are parsed correctly.
    # All other tests in this class just mock the call (using assert_called_with) to make the tests quicker.
    def test_structure_dump
      assert_equal "", File.read(@filename)

      config = @configuration.dup
      config["database"] = ARTest.config["connections"]["postgresql"]["arunit"]["database"]

      ActiveRecord::Tasks::DatabaseTasks.structure_dump(config, @filename)

      assert File.read(@filename).include?("PostgreSQL database dump complete")
    end

    def test_structure_dump_header_comments_removed
      Kernel.stub(:system, true) do
        File.write(@filename, "-- header comment\n\n-- more header comment\n statement \n-- lower comment\n")
        ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)

        assert_equal [" statement \n", "-- lower comment\n"], File.readlines(@filename).first(2)
      end
    end

    def test_structure_dump_with_env
      expected_env = { "PGHOST" => "my.server.tld", "PGPORT" => "2345", "PGUSER" => "jane", "PGPASSWORD" => "s3cr3t" }
      expected_command = [expected_env, "pg_dump", "--schema-only", "--no-privileges", "--no-owner", "--file", @filename, "my-app-db"]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        ActiveRecord::Tasks::DatabaseTasks.structure_dump(
          @configuration.merge(host: "my.server.tld", port: 2345, username: "jane", password: "s3cr3t"),
          @filename
        )
      end
    end

    def test_structure_dump_with_ssl_env
      expected_env = { "PGSSLMODE" => "verify-full", "PGSSLCERT" => "client.crt", "PGSSLKEY" => "client.key", "PGSSLROOTCERT" => "root.crt" }
      expected_command = [expected_env, "pg_dump", "--schema-only", "--no-privileges", "--no-owner", "--file", @filename, "my-app-db"]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        ActiveRecord::Tasks::DatabaseTasks.structure_dump(
          @configuration.merge(sslmode: "verify-full", sslcert: "client.crt", sslkey: "client.key", sslrootcert: "root.crt"),
          @filename
        )
      end
    end

    def test_structure_dump_with_extra_flags
      expected_command = [{}, "pg_dump", "--schema-only", "--no-privileges", "--no-owner", "--file", @filename, "--noop", "my-app-db"]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_dump_flags(["--noop"]) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
        end
      end
    end

    def test_structure_dump_with_hash_extra_flags_for_a_different_driver
      expected_command = [{}, "pg_dump", "--schema-only", "--no-privileges", "--no-owner", "--file", @filename, "my-app-db"]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_dump_flags({ mysql2: ["--noop"] }) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
        end
      end
    end

    def test_structure_dump_with_hash_extra_flags_for_the_correct_driver
      expected_command = [{}, "pg_dump", "--schema-only", "--no-privileges", "--no-owner", "--file", @filename, "--noop", "my-app-db"]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_dump_flags({ postgresql: ["--noop"] }) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
        end
      end
    end

    def test_structure_dump_with_ignore_tables
      ActiveRecord::Base.lease_connection.stub(:data_sources, ["foo", "bar", "prefix_foo", "ignored_foo"]) do
        ActiveRecord::SchemaDumper.stub(:ignore_tables, [/^prefix_/, "ignored_foo"]) do
          assert_called_with(
            Kernel,
            :system,
            [{}, "pg_dump", "--schema-only", "--no-privileges", "--no-owner", "--file", @filename, "-T", "prefix_foo", "-T", "ignored_foo", "my-app-db"],
            returns: true
          ) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump(@configuration, @filename)
          end
        end
      end
    end

    def test_structure_dump_with_schema_search_path
      @configuration["schema_search_path"] = "foo,bar"

      assert_called_with(
        Kernel,
        :system,
        [{}, "pg_dump", "--schema-only", "--no-privileges", "--no-owner", "--file", @filename, "--schema=foo", "--schema=bar", "my-app-db"],
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
        [{}, "pg_dump", "--schema-only", "--no-privileges", "--no-owner", "--file", @filename,  "my-app-db"],
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
        [{}, "pg_dump", "--schema-only", "--no-privileges", "--no-owner", "--file", @filename, "--schema=foo", "--schema=bar", "my-app-db"],
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
        [{}, "pg_dump", "--schema-only", "--no-privileges", "--no-owner", "--file", filename, "my-app-db"],
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
        old_dump_schemas = ActiveRecord.dump_schemas
        ActiveRecord.dump_schemas = value
        yield
      ensure
        ActiveRecord.dump_schemas = old_dump_schemas
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
        [{}, "psql", "--set", "ON_ERROR_STOP=1", "--quiet", "--no-psqlrc", "--output", File::NULL, "--file", filename, @configuration["database"]],
        returns: true
      ) do
        ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
      end
    end

    def test_structure_load_with_extra_flags
      filename = "awesome-file.sql"
      expected_command = [{}, "psql", "--set", "ON_ERROR_STOP=1", "--quiet", "--no-psqlrc", "--output", File::NULL, "--file", filename, "--noop", @configuration["database"]]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_load_flags(["--noop"]) do
          ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
        end
      end
    end

    def test_structure_load_with_env
      filename = "awesome-file.sql"
      expected_env = { "PGHOST" => "my.server.tld", "PGPORT" => "2345", "PGUSER" => "jane", "PGPASSWORD" => "s3cr3t" }
      expected_command = [expected_env, "psql", "--set", "ON_ERROR_STOP=1", "--quiet", "--no-psqlrc", "--output", File::NULL, "--file", filename, "--noop", @configuration["database"]]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_load_flags(["--noop"]) do
          ActiveRecord::Tasks::DatabaseTasks.structure_load(
            @configuration.merge(host: "my.server.tld", port: 2345, username: "jane", password: "s3cr3t"),
            filename
          )
        end
      end
    end

    def test_structure_load_with_ssl_env
      filename = "awesome-file.sql"
      expected_env = { "PGSSLMODE" => "verify-full", "PGSSLCERT" => "client.crt", "PGSSLKEY" => "client.key", "PGSSLROOTCERT" => "root.crt" }
      expected_command = [expected_env, "psql", "--set", "ON_ERROR_STOP=1", "--quiet", "--no-psqlrc", "--output", File::NULL, "--file", filename, "--noop", @configuration["database"]]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_load_flags(["--noop"]) do
          ActiveRecord::Tasks::DatabaseTasks.structure_load(
            @configuration.merge(sslmode: "verify-full", sslcert: "client.crt", sslkey: "client.key", sslrootcert: "root.crt"),
            filename
          )
        end
      end
    end

    def test_structure_load_with_hash_extra_flags_for_a_different_driver
      filename = "awesome-file.sql"
      expected_command = [{}, "psql", "--set", "ON_ERROR_STOP=1", "--quiet", "--no-psqlrc", "--output", File::NULL, "--file", filename, @configuration["database"]]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_load_flags({ mysql2: ["--noop"] }) do
          ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
        end
      end
    end

    def test_structure_load_with_hash_extra_flags_for_the_correct_driver
      filename = "awesome-file.sql"
      expected_command = [{}, "psql", "--set", "ON_ERROR_STOP=1", "--quiet", "--no-psqlrc", "--output", File::NULL, "--file", filename, "--noop", @configuration["database"]]

      assert_called_with(Kernel, :system, expected_command, returns: true) do
        with_structure_load_flags({ postgresql: ["--noop"] }) do
          ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
        end
      end
    end

    def test_structure_load_accepts_path_with_spaces
      filename = "awesome file.sql"
      assert_called_with(
        Kernel,
        :system,
        [{}, "psql", "--set", "ON_ERROR_STOP=1", "--quiet", "--no-psqlrc", "--output", File::NULL, "--file", filename, @configuration["database"]],
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
