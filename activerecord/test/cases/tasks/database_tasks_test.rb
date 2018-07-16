# frozen_string_literal: true

require "cases/helper"
require "active_record/tasks/database_tasks"

module ActiveRecord
  module DatabaseTasksSetupper
    def setup
      @mysql_tasks, @postgresql_tasks, @sqlite_tasks = Array.new(
        3,
        Class.new do
          def create; end
          def drop; end
          def purge; end
          def charset; end
          def collation; end
          def structure_dump(*); end
        end.new
      )

      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
    end

    def with_stubbed_new
      ActiveRecord::Tasks::MySQLDatabaseTasks.stub(:new, @mysql_tasks) do
        ActiveRecord::Tasks::PostgreSQLDatabaseTasks.stub(:new, @postgresql_tasks) do
          ActiveRecord::Tasks::SQLiteDatabaseTasks.stub(:new, @sqlite_tasks) do
            yield
          end
        end
      end
    end
  end

  ADAPTERS_TASKS = {
    mysql2:     :mysql_tasks,
    postgresql: :postgresql_tasks,
    sqlite3:    :sqlite_tasks
  }

  class DatabaseTasksUtilsTask < ActiveRecord::TestCase
    def test_raises_an_error_when_called_with_protected_environment
      ActiveRecord::MigrationContext.any_instance.stubs(:current_version).returns(1)

      protected_environments = ActiveRecord::Base.protected_environments
      current_env            = ActiveRecord::Base.connection.migration_context.current_environment
      assert_not_includes protected_environments, current_env
      # Assert no error
      ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!

      ActiveRecord::Base.protected_environments = [current_env]

      assert_raise(ActiveRecord::ProtectedEnvironmentError) do
        ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
      end
    ensure
      ActiveRecord::Base.protected_environments = protected_environments
    end

    def test_raises_an_error_when_called_with_protected_environment_which_name_is_a_symbol
      ActiveRecord::MigrationContext.any_instance.stubs(:current_version).returns(1)

      protected_environments = ActiveRecord::Base.protected_environments
      current_env            = ActiveRecord::Base.connection.migration_context.current_environment
      assert_not_includes protected_environments, current_env
      # Assert no error
      ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!

      ActiveRecord::Base.protected_environments = [current_env.to_sym]
      assert_raise(ActiveRecord::ProtectedEnvironmentError) do
        ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
      end
    ensure
      ActiveRecord::Base.protected_environments = protected_environments
    end

    def test_raises_an_error_if_no_migrations_have_been_made
      ActiveRecord::InternalMetadata.stub(:table_exists?, false) do
        ActiveRecord::MigrationContext.any_instance.stubs(:current_version).returns(1)

        assert_raise(ActiveRecord::NoEnvironmentInSchemaError) do
          ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
        end
      end
    end
  end

  class DatabaseTasksRegisterTask < ActiveRecord::TestCase
    def test_register_task
      klazz = Class.new do
        def initialize(*arguments); end
        def structure_dump(filename); end
      end
      instance = klazz.new

      klazz.stub(:new, instance) do
        assert_called_with(instance, :structure_dump, ["awesome-file.sql", nil]) do
          ActiveRecord::Tasks::DatabaseTasks.register_task(/foo/, klazz)
          ActiveRecord::Tasks::DatabaseTasks.structure_dump({ "adapter" => :foo }, "awesome-file.sql")
        end
      end
    end

    def test_unregistered_task
      assert_raise(ActiveRecord::Tasks::DatabaseNotSupported) do
        ActiveRecord::Tasks::DatabaseTasks.structure_dump({ "adapter" => :bar }, "awesome-file.sql")
      end
    end
  end

  class DatabaseTasksCreateTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_create") do
        with_stubbed_new do
          eval("@#{v}").expects(:create)
          ActiveRecord::Tasks::DatabaseTasks.create "adapter" => k
        end
      end
    end
  end

  class DatabaseTasksDumpSchemaCacheTest < ActiveRecord::TestCase
    def test_dump_schema_cache
      path = "/tmp/my_schema_cache.yml"
      ActiveRecord::Tasks::DatabaseTasks.dump_schema_cache(ActiveRecord::Base.connection, path)
      assert File.file?(path)
    ensure
      ActiveRecord::Base.clear_cache!
      FileUtils.rm_rf(path)
    end
  end

  class DatabaseTasksCreateAllTest < ActiveRecord::TestCase
    def setup
      @configurations = { "development" => { "database" => "my-db" } }

      # To refrain from connecting to a newly created empty DB in sqlite3_mem tests
      ActiveRecord::Base.connection_handler.stubs(:establish_connection)

      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
    end

    def test_ignores_configurations_without_databases
      @configurations["development"].merge!("database" => nil)

      with_stubbed_configurations do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_ignores_remote_databases
      @configurations["development"].merge!("host" => "my.server.tld")

      with_stubbed_configurations do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_warning_for_remote_databases
      @configurations["development"].merge!("host" => "my.server.tld")

      with_stubbed_configurations do
        ActiveRecord::Tasks::DatabaseTasks.create_all

        assert_match "This task only modifies local databases. my-db is on a remote host.",
          $stderr.string
      end
    end

    def test_creates_configurations_with_local_ip
      @configurations["development"].merge!("host" => "127.0.0.1")

      with_stubbed_configurations do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_creates_configurations_with_local_host
      @configurations["development"].merge!("host" => "localhost")

      with_stubbed_configurations do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_creates_configurations_with_blank_hosts
      @configurations["development"].merge!("host" => nil)

      with_stubbed_configurations do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    private

      def with_stubbed_configurations
        ActiveRecord::Base.stub(:configurations, @configurations) do
          yield
        end
      end
  end

  class DatabaseTasksCreateCurrentTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "url" => "prod-db-url" }
      }
    end

    def test_creates_current_environment_database
      with_stubbed_configurations_establish_connection do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :create,
          ["database" => "test-db"],
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create_current(
            ActiveSupport::StringInquirer.new("test")
          )
        end
      end
    end

    def test_creates_current_environment_database_with_url
      with_stubbed_configurations_establish_connection do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :create,
          ["url" => "prod-db-url"],
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create_current(
            ActiveSupport::StringInquirer.new("production")
          )
        end
      end
    end

    def test_creates_test_and_development_databases_when_env_was_not_specified
      with_stubbed_configurations_establish_connection do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :create,
          [
            ["database" => "dev-db"],
            ["database" => "test-db"]
          ],
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create_current(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    end

    def test_creates_test_and_development_databases_when_rails_env_is_development
      old_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "development"

      with_stubbed_configurations_establish_connection do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :create,
          [
            ["database" => "dev-db"],
            ["database" => "test-db"]
          ],
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create_current(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    ensure
      ENV["RAILS_ENV"] = old_env
    end

    def test_establishes_connection_for_the_given_environments
      ActiveRecord::Tasks::DatabaseTasks.stub(:create, nil) do
        assert_called_with(ActiveRecord::Base, :establish_connection, [:development]) do
          ActiveRecord::Tasks::DatabaseTasks.create_current(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    end

    private

      def with_stubbed_configurations_establish_connection
        ActiveRecord::Base.stub(:configurations, @configurations) do
          ActiveRecord::Base.stub(:establish_connection, nil) do
            yield
          end
        end
      end
  end

  class DatabaseTasksCreateCurrentThreeTierTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "primary" => { "database" => "dev-db" }, "secondary" => { "database" => "secondary-dev-db" } },
        "test" => { "primary" => { "database" => "test-db" }, "secondary" => { "database" => "secondary-test-db" } },
        "production" => { "primary" => { "url" => "prod-db-url" }, "secondary" => { "url" => "secondary-prod-db-url" } }
      }
    end

    def test_creates_current_environment_database
      with_stubbed_configurations_establish_connection do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :create,
          [
            ["database" => "test-db"],
            ["database" => "secondary-test-db"]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create_current(
            ActiveSupport::StringInquirer.new("test")
          )
        end
      end
    end

    def test_creates_current_environment_database_with_url
      with_stubbed_configurations_establish_connection do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :create,
          [
            ["url" => "prod-db-url"],
            ["url" => "secondary-prod-db-url"]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create_current(
            ActiveSupport::StringInquirer.new("production")
          )
        end
      end
    end

    def test_creates_test_and_development_databases_when_env_was_not_specified
      with_stubbed_configurations_establish_connection do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :create,
          [
            ["database" => "dev-db"],
            ["database" => "secondary-dev-db"],
            ["database" => "test-db"],
            ["database" => "secondary-test-db"]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create_current(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    end

    def test_creates_test_and_development_databases_when_rails_env_is_development
      old_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "development"

      with_stubbed_configurations_establish_connection do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :create,
          [
            ["database" => "dev-db"],
            ["database" => "secondary-dev-db"],
            ["database" => "test-db"],
            ["database" => "secondary-test-db"]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create_current(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    ensure
      ENV["RAILS_ENV"] = old_env
    end

    def test_establishes_connection_for_the_given_environments_config
      ActiveRecord::Tasks::DatabaseTasks.stub(:create, nil) do
        ActiveRecord::Base.expects(:establish_connection).with(:development)

        ActiveRecord::Tasks::DatabaseTasks.create_current(
          ActiveSupport::StringInquirer.new("development")
        )
      end
    end

    private

      def with_stubbed_configurations_establish_connection
        ActiveRecord::Base.stub(:configurations, @configurations) do
          ActiveRecord::Base.stub(:establish_connection, nil) do
            yield
          end
        end
      end
  end

  class DatabaseTasksDropTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_drop") do
        with_stubbed_new do
          eval("@#{v}").expects(:drop)
          ActiveRecord::Tasks::DatabaseTasks.drop "adapter" => k
        end
      end
    end
  end

  class DatabaseTasksDropAllTest < ActiveRecord::TestCase
    def setup
      @configurations = { development: { "database" => "my-db" } }

      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
    end

    def test_ignores_configurations_without_databases
      @configurations[:development].merge!("database" => nil)

      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_ignores_remote_databases
      @configurations[:development].merge!("host" => "my.server.tld")

      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_warning_for_remote_databases
      @configurations[:development].merge!("host" => "my.server.tld")

      ActiveRecord::Base.stub(:configurations, @configurations) do
        ActiveRecord::Tasks::DatabaseTasks.drop_all

        assert_match "This task only modifies local databases. my-db is on a remote host.",
          $stderr.string
      end
    end

    def test_drops_configurations_with_local_ip
      @configurations[:development].merge!("host" => "127.0.0.1")

      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_drops_configurations_with_local_host
      @configurations[:development].merge!("host" => "localhost")

      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_drops_configurations_with_blank_hosts
      @configurations[:development].merge!("host" => nil)

      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end
  end

  class DatabaseTasksDropCurrentTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "url" => "prod-db-url" }
      }
    end

    def test_drops_current_environment_database
      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_called_with(ActiveRecord::Tasks::DatabaseTasks, :drop,
          ["database" => "test-db"]) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("test")
          )
        end
      end
    end

    def test_drops_current_environment_database_with_url
      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_called_with(ActiveRecord::Tasks::DatabaseTasks, :drop,
          ["url" => "prod-db-url"]) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("production")
          )
        end
      end
    end

    def test_drops_test_and_development_databases_when_env_was_not_specified
      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            ["database" => "dev-db"],
            ["database" => "test-db"]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    end

    def test_drops_testand_development_databases_when_rails_env_is_development
      old_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "development"

      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            ["database" => "dev-db"],
            ["database" => "test-db"]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    ensure
      ENV["RAILS_ENV"] = old_env
    end
  end

  class DatabaseTasksDropCurrentThreeTierTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "primary" => { "database" => "dev-db" }, "secondary" => { "database" => "secondary-dev-db" } },
        "test" => { "primary" => { "database" => "test-db" }, "secondary" => { "database" => "secondary-test-db" } },
        "production" => { "primary" => { "url" => "prod-db-url" }, "secondary" => { "url" => "secondary-prod-db-url" } }
      }
    end

    def test_drops_current_environment_database
      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            ["database" => "test-db"],
            ["database" => "secondary-test-db"]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("test")
          )
        end
      end
    end

    def test_drops_current_environment_database_with_url
      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            ["url" => "prod-db-url"],
            ["url" => "secondary-prod-db-url"]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("production")
          )
        end
      end
    end

    def test_drops_test_and_development_databases_when_env_was_not_specified
      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            ["database" => "dev-db"],
            ["database" => "secondary-dev-db"],
            ["database" => "test-db"],
            ["database" => "secondary-test-db"]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    end

    def test_drops_testand_development_databases_when_rails_env_is_development
      old_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "development"

      ActiveRecord::Base.stub(:configurations, @configurations) do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            ["database" => "dev-db"],
            ["database" => "secondary-dev-db"],
            ["database" => "test-db"],
            ["database" => "secondary-test-db"]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    ensure
      ENV["RAILS_ENV"] = old_env
    end
  end

  if current_adapter?(:SQLite3Adapter) && !in_memory_db?
    class DatabaseTasksMigrateTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      # Use a memory db here to avoid having to rollback at the end
      setup do
        migrations_path = MIGRATIONS_ROOT + "/valid"
        file = ActiveRecord::Base.connection.raw_connection.filename
        @conn = ActiveRecord::Base.establish_connection adapter: "sqlite3",
          database: ":memory:", migrations_paths: migrations_path
        source_db = SQLite3::Database.new file
        dest_db = ActiveRecord::Base.connection.raw_connection
        backup = SQLite3::Backup.new(dest_db, "main", source_db, "main")
        backup.step(-1)
        backup.finish
      end

      teardown do
        @conn.release_connection if @conn
        ActiveRecord::Base.establish_connection :arunit
      end

      def test_migrate_set_and_unset_verbose_and_version_env_vars
        verbose, version = ENV["VERBOSE"], ENV["VERSION"]
        ENV["VERSION"] = "2"
        ENV["VERBOSE"] = "false"

        # run down migration because it was already run on copied db
        assert_empty capture_migration_output

        ENV.delete("VERSION")
        ENV.delete("VERBOSE")

        # re-run up migration
        assert_includes capture_migration_output, "migrating"
      ensure
        ENV["VERBOSE"], ENV["VERSION"] = verbose, version
      end

      def test_migrate_set_and_unset_empty_values_for_verbose_and_version_env_vars
        verbose, version = ENV["VERBOSE"], ENV["VERSION"]

        ENV["VERSION"] = "2"
        ENV["VERBOSE"] = "false"

        # run down migration because it was already run on copied db
        assert_empty capture_migration_output

        ENV["VERBOSE"] = ""
        ENV["VERSION"] = ""

        # re-run up migration
        assert_includes capture_migration_output, "migrating"
      ensure
        ENV["VERBOSE"], ENV["VERSION"] = verbose, version
      end

      def test_migrate_set_and_unset_nonsense_values_for_verbose_and_version_env_vars
        verbose, version = ENV["VERBOSE"], ENV["VERSION"]

        # run down migration because it was already run on copied db
        ENV["VERSION"] = "2"
        ENV["VERBOSE"] = "false"

        assert_empty capture_migration_output

        ENV["VERBOSE"] = "yes"
        ENV["VERSION"] = "2"

        # run no migration because 2 was already run
        assert_empty capture_migration_output
      ensure
        ENV["VERBOSE"], ENV["VERSION"] = verbose, version
      end

      private
        def capture_migration_output
          capture(:stdout) do
            ActiveRecord::Tasks::DatabaseTasks.migrate
          end
        end
    end
  end

  class DatabaseTasksMigrateErrorTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    def test_migrate_raise_error_on_invalid_version_format
      version = ENV["VERSION"]

      ENV["VERSION"] = "unknown"
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "0.1.11"
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1.1.11"
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "0 "
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1."
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1_"
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1_name"
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.migrate }
      assert_match(/Invalid format of target version/, e.message)
    ensure
      ENV["VERSION"] = version
    end

    def test_migrate_raise_error_on_failed_check_target_version
      ActiveRecord::Tasks::DatabaseTasks.stub(:check_target_version, -> { raise "foo" }) do
        e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.migrate }
        assert_equal "foo", e.message
      end
    end

    def test_migrate_clears_schema_cache_afterward
      assert_called(ActiveRecord::Base, :clear_cache!) do
        ActiveRecord::Tasks::DatabaseTasks.migrate
      end
    end
  end

  class DatabaseTasksPurgeTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_purge") do
        with_stubbed_new do
          eval("@#{v}").expects(:purge)
          ActiveRecord::Tasks::DatabaseTasks.purge "adapter" => k
        end
      end
    end
  end

  class DatabaseTasksPurgeCurrentTest < ActiveRecord::TestCase
    def test_purges_current_environment_database
      configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "database" => "prod-db" }
      }
      ActiveRecord::Base.stub(:configurations, configurations) do
        ActiveRecord::Tasks::DatabaseTasks.expects(:purge).
          with("database" => "prod-db")

        assert_called_with(ActiveRecord::Base, :establish_connection, [:production]) do
          ActiveRecord::Tasks::DatabaseTasks.purge_current("production")
        end
      end
    end
  end

  class DatabaseTasksPurgeAllTest < ActiveRecord::TestCase
    def test_purge_all_local_configurations
      configurations = { development: { "database" => "my-db" } }
      ActiveRecord::Base.stub(:configurations, configurations) do
        ActiveRecord::Tasks::DatabaseTasks.expects(:purge).
          with("database" => "my-db")

        ActiveRecord::Tasks::DatabaseTasks.purge_all
      end
    end
  end

  class DatabaseTasksCharsetTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_charset") do
        with_stubbed_new do
          eval("@#{v}").expects(:charset)
          ActiveRecord::Tasks::DatabaseTasks.charset "adapter" => k
        end
      end
    end
  end

  class DatabaseTasksCollationTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_collation") do
        with_stubbed_new do
          eval("@#{v}").expects(:collation)
          ActiveRecord::Tasks::DatabaseTasks.collation "adapter" => k
        end
      end
    end
  end

  class DatabaseTaskTargetVersionTest < ActiveRecord::TestCase
    def test_target_version_returns_nil_if_version_does_not_exist
      version = ENV.delete("VERSION")
      assert_nil ActiveRecord::Tasks::DatabaseTasks.target_version
    ensure
      ENV["VERSION"] = version
    end

    def test_target_version_returns_nil_if_version_is_empty
      version = ENV["VERSION"]

      ENV["VERSION"] = ""
      assert_nil ActiveRecord::Tasks::DatabaseTasks.target_version
    ensure
      ENV["VERSION"] = version
    end

    def test_target_version_returns_converted_to_integer_env_version_if_version_exists
      version = ENV["VERSION"]

      ENV["VERSION"] = "0"
      assert_equal ENV["VERSION"].to_i, ActiveRecord::Tasks::DatabaseTasks.target_version

      ENV["VERSION"] = "42"
      assert_equal ENV["VERSION"].to_i, ActiveRecord::Tasks::DatabaseTasks.target_version

      ENV["VERSION"] = "042"
      assert_equal ENV["VERSION"].to_i, ActiveRecord::Tasks::DatabaseTasks.target_version
    ensure
      ENV["VERSION"] = version
    end
  end

  class DatabaseTaskCheckTargetVersionTest < ActiveRecord::TestCase
    def test_check_target_version_does_not_raise_error_on_empty_version
      version = ENV["VERSION"]
      ENV["VERSION"] = ""
      assert_nothing_raised { ActiveRecord::Tasks::DatabaseTasks.check_target_version }
    ensure
      ENV["VERSION"] = version
    end

    def test_check_target_version_does_not_raise_error_if_version_is_not_setted
      version = ENV.delete("VERSION")
      assert_nothing_raised { ActiveRecord::Tasks::DatabaseTasks.check_target_version }
    ensure
      ENV["VERSION"] = version
    end

    def test_check_target_version_raises_error_on_invalid_version_format
      version = ENV["VERSION"]

      ENV["VERSION"] = "unknown"
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "0.1.11"
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1.1.11"
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "0 "
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1."
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1_"
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)

      ENV["VERSION"] = "1_name"
      e = assert_raise(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.check_target_version }
      assert_match(/Invalid format of target version/, e.message)
    ensure
      ENV["VERSION"] = version
    end

    def test_check_target_version_does_not_raise_error_on_valid_version_format
      version = ENV["VERSION"]

      ENV["VERSION"] = "0"
      assert_nothing_raised { ActiveRecord::Tasks::DatabaseTasks.check_target_version }

      ENV["VERSION"] = "1"
      assert_nothing_raised { ActiveRecord::Tasks::DatabaseTasks.check_target_version }

      ENV["VERSION"] = "001"
      assert_nothing_raised { ActiveRecord::Tasks::DatabaseTasks.check_target_version }

      ENV["VERSION"] = "001_name.rb"
      assert_nothing_raised { ActiveRecord::Tasks::DatabaseTasks.check_target_version }
    ensure
      ENV["VERSION"] = version
    end
  end

  class DatabaseTasksStructureDumpTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_structure_dump") do
        with_stubbed_new do
          eval("@#{v}").expects(:structure_dump).with("awesome-file.sql", nil)
          ActiveRecord::Tasks::DatabaseTasks.structure_dump({ "adapter" => k }, "awesome-file.sql")
        end
      end
    end
  end

  class DatabaseTasksStructureLoadTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_structure_load") do
        with_stubbed_new do
          eval("@#{v}").expects(:structure_load).with("awesome-file.sql", nil)
          ActiveRecord::Tasks::DatabaseTasks.structure_load({ "adapter" => k }, "awesome-file.sql")
        end
      end
    end
  end

  class DatabaseTasksCheckSchemaFileTest < ActiveRecord::TestCase
    def test_check_schema_file
      assert_called_with(Kernel, :abort, [/awesome-file.sql/]) do
        ActiveRecord::Tasks::DatabaseTasks.check_schema_file("awesome-file.sql")
      end
    end
  end

  class DatabaseTasksCheckSchemaFileDefaultsTest < ActiveRecord::TestCase
    def test_check_schema_file_defaults
      ActiveRecord::Tasks::DatabaseTasks.stub(:db_dir, "/tmp") do
        assert_equal "/tmp/schema.rb", ActiveRecord::Tasks::DatabaseTasks.schema_file
      end
    end
  end

  class DatabaseTasksCheckSchemaFileSpecifiedFormatsTest < ActiveRecord::TestCase
    { ruby: "schema.rb", sql: "structure.sql" }.each_pair do |fmt, filename|
      define_method("test_check_schema_file_for_#{fmt}_format") do
        ActiveRecord::Tasks::DatabaseTasks.stub(:db_dir, "/tmp") do
          assert_equal "/tmp/#{filename}", ActiveRecord::Tasks::DatabaseTasks.schema_file(fmt)
        end
      end
    end
  end
end
