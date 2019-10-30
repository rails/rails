# frozen_string_literal: true

require "cases/helper"
require "active_record/tasks/database_tasks"
require "models/author"

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
          def charset_current; end
          def collation; end
          def collation_current; end
          def structure_dump(*); end
          def structure_load(*); end
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
    def teardown
      ActiveRecord::Tasks::DatabaseTasks.current_config = nil
    end

    if current_adapter?(:SQLite3Adapter) && !in_memory_db?
      def test_checking_the_protected_environment_does_not_create_a_new_db_if_does_not_exist
        current_env = ActiveRecord::Base.connection.migration_context.current_environment
        database    = "non_existent_database.sqlite3"

        @configurations = {
          current_env.to_sym => {
            "database" => database,
            "adapter" => "sqlite3"
          }
        }

        with_stubbed_configurations_establish_connection do
          ActiveRecord::Tasks::DatabaseTasks.stub(:root, "") do
            ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
          end
        end

        assert_not File.exist?(database), "Expected #{database} to not exist"
      end
    end

    def test_raises_an_error_when_called_with_protected_environment
      protected_environments = ActiveRecord::Base.protected_environments
      current_env            = ActiveRecord::Base.connection.migration_context.current_environment
      @configurations        = { current_env.to_sym => ActiveRecord::Base.configurations["arunit"] }

      InternalMetadata[:environment] = current_env

      assert_called_on_instance_of(
        ActiveRecord::MigrationContext,
        :current_version,
        times: 6,
        returns: 1
      ) do
        assert_not_includes protected_environments, current_env

        with_stubbed_configurations_establish_connection do
          ActiveRecord::Tasks::DatabaseTasks.stub(:root, "") do
            # Assert no error
            ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!

            ActiveRecord::Base.protected_environments = [current_env]

            assert_raise(ActiveRecord::ProtectedEnvironmentError) do
              ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
            end
          end
        end
      end
    ensure
      ActiveRecord::Base.protected_environments = protected_environments
    end

    def test_raises_an_error_when_called_with_protected_environment_which_name_is_a_symbol
      current_env            = ActiveRecord::Base.connection.migration_context.current_environment
      protected_environments = ActiveRecord::Base.protected_environments
      @configurations        = { current_env.to_sym => ActiveRecord::Base.configurations["arunit"] }

      InternalMetadata[:environment] = current_env

      assert_called_on_instance_of(
        ActiveRecord::MigrationContext,
        :current_version,
        times: 6,
        returns: 1
      ) do
        assert_not_includes protected_environments, current_env

        with_stubbed_configurations_establish_connection do
          ActiveRecord::Tasks::DatabaseTasks.stub(:root, "") do
            # Assert no error
            ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!

            ActiveRecord::Base.protected_environments = [current_env.to_sym]
            assert_raise(ActiveRecord::ProtectedEnvironmentError) do
              ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
            end
          end
        end
      end
    ensure
      ActiveRecord::Base.protected_environments = protected_environments
    end

    def test_raises_an_error_if_no_migrations_have_been_made
      current_env            = ActiveRecord::Base.connection.migration_context.current_environment
      @configurations        = { current_env.to_sym => ActiveRecord::Base.configurations["arunit"] }

      ActiveRecord::InternalMetadata.stub(:table_exists?, false) do
        assert_called_on_instance_of(
          ActiveRecord::MigrationContext,
          :current_version,
          returns: 1
        ) do
          with_stubbed_configurations_establish_connection do
            ActiveRecord::Tasks::DatabaseTasks.stub(:root, "") do
              assert_raise(ActiveRecord::NoEnvironmentInSchemaError) do
                ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
              end
            end
          end
        end
      end
    end

    private

      def with_stubbed_configurations_establish_connection
        old_configurations = ActiveRecord::Base.configurations
        ActiveRecord::Base.configurations = @configurations

        ActiveRecord::Base.connection_handler.stub(:establish_connection, nil) do
          yield
        end
      ensure
        ActiveRecord::Base.configurations = old_configurations
      end
  end

  class DatabaseTasksCurrentConfigTask < ActiveRecord::TestCase
    def test_current_config_set
      hash = {}

      with_stubbed_configurations do
        ActiveRecord::Tasks::DatabaseTasks.current_config(config: hash, env: "production")

        assert_equal hash, ActiveRecord::Tasks::DatabaseTasks.current_config(env: "production")
      end
    end

    def test_current_config_read_none_found
      with_stubbed_configurations do
        config = ActiveRecord::Tasks::DatabaseTasks.current_config(env: "production", spec: "empty")

        assert_nil config
      end
    end

    def test_current_config_read_found
      with_stubbed_configurations do
        config = ActiveRecord::Tasks::DatabaseTasks.current_config(env: "production", spec: "exists")

        assert_equal({ database: "my-db" }, config)
      end
    end

    def test_current_config_read_after_set
      hash = {}

      with_stubbed_configurations do
        ActiveRecord::Tasks::DatabaseTasks.current_config(config: hash, env: "production")

        config = ActiveRecord::Tasks::DatabaseTasks.current_config(env: "production", spec: "exists")

        assert_equal hash, config
      end
    end

    private
      def with_stubbed_configurations
        old_configurations = ActiveRecord::Base.configurations
        ActiveRecord::Base.configurations = { "production" => { "exists" => { "database" => "my-db" } } }

        assert_deprecated do
          yield
        end
      ensure
        ActiveRecord::Base.configurations = old_configurations
        assert_deprecated do
          ActiveRecord::Tasks::DatabaseTasks.current_config = nil
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
          assert_called(eval("@#{v}"), :create) do
            ActiveRecord::Tasks::DatabaseTasks.create "adapter" => k
          end
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

      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
    end

    def test_ignores_configurations_without_databases
      @configurations["development"]["database"] = nil

      with_stubbed_configurations_establish_connection do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_ignores_remote_databases
      @configurations["development"]["host"] = "my.server.tld"

      with_stubbed_configurations_establish_connection do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_warning_for_remote_databases
      @configurations["development"]["host"] = "my.server.tld"

      with_stubbed_configurations_establish_connection do
        ActiveRecord::Tasks::DatabaseTasks.create_all

        assert_match "This task only modifies local databases. my-db is on a remote host.",
          $stderr.string
      end
    end

    def test_creates_configurations_with_local_ip
      @configurations["development"]["host"] = "127.0.0.1"

      with_stubbed_configurations_establish_connection do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_creates_configurations_with_local_host
      @configurations["development"]["host"] = "localhost"

      with_stubbed_configurations_establish_connection do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_creates_configurations_with_blank_hosts
      @configurations["development"]["host"] = nil

      with_stubbed_configurations_establish_connection do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    private
      def with_stubbed_configurations_establish_connection
        old_configurations = ActiveRecord::Base.configurations
        ActiveRecord::Base.configurations = @configurations

        # To refrain from connecting to a newly created empty DB in
        # sqlite3_mem tests
        ActiveRecord::Base.connection_handler.stub(:establish_connection, nil) do
          yield
        end
      ensure
        ActiveRecord::Base.configurations = old_configurations
      end
  end

  class DatabaseTasksCreateCurrentTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "url" => "abstract://prod-db-host/prod-db" }
      }
    end

    def test_creates_current_environment_database
      with_stubbed_configurations_establish_connection do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :create,
          [config_for("test", "primary")]
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
          [config_for("production", "primary")]
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
            [config_for("development", "primary")],
            [config_for("test", "primary")]
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
            [config_for("development", "primary")],
            [config_for("test", "primary")]
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
      def config_for(env_name, spec_name)
        ActiveRecord::Base.configurations.configs_for(env_name: env_name, spec_name: spec_name)
      end

      def with_stubbed_configurations_establish_connection
        old_configurations = ActiveRecord::Base.configurations
        ActiveRecord::Base.configurations = @configurations

        ActiveRecord::Base.connection_handler.stub(:establish_connection, nil) do
          yield
        end
      ensure
        ActiveRecord::Base.configurations = old_configurations
      end
  end

  class DatabaseTasksCreateCurrentThreeTierTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "primary" => { "database" => "dev-db" }, "secondary" => { "database" => "secondary-dev-db" } },
        "test" => { "primary" => { "database" => "test-db" }, "secondary" => { "database" => "secondary-test-db" } },
        "production" => { "primary" => { "url" => "abstract://prod-db-host/prod-db" }, "secondary" => { "url" => "abstract://secondary-prod-db-host/secondary-prod-db" } }
      }
    end

    def test_creates_current_environment_database
      with_stubbed_configurations_establish_connection do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :create,
          [
            [config_for("test", "primary")],
            [config_for("test", "secondary")]
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
            [config_for("production", "primary")],
            [config_for("production", "secondary")]
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
            [config_for("development", "primary")],
            [config_for("development", "secondary")],
            [config_for("test", "primary")],
            [config_for("test", "secondary")]
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
            [config_for("development", "primary")],
            [config_for("development", "secondary")],
            [config_for("test", "primary")],
            [config_for("test", "secondary")]
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
        assert_called_with(
          ActiveRecord::Base,
          :establish_connection,
          [:development]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.create_current(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    end

    private
      def config_for(env_name, spec_name)
        ActiveRecord::Base.configurations.configs_for(env_name: env_name, spec_name: spec_name)
      end

      def with_stubbed_configurations_establish_connection
        old_configurations = ActiveRecord::Base.configurations
        ActiveRecord::Base.configurations = @configurations

        ActiveRecord::Base.connection_handler.stub(:establish_connection, nil) do
          yield
        end
      ensure
        ActiveRecord::Base.configurations = old_configurations
      end
  end

  class DatabaseTasksDropTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_drop") do
        with_stubbed_new do
          assert_called(eval("@#{v}"), :drop) do
            ActiveRecord::Tasks::DatabaseTasks.drop "adapter" => k
          end
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
      @configurations[:development]["database"] = nil

      with_stubbed_configurations do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_ignores_remote_databases
      @configurations[:development]["host"] = "my.server.tld"

      with_stubbed_configurations do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_warning_for_remote_databases
      @configurations[:development]["host"] = "my.server.tld"

      with_stubbed_configurations do
        ActiveRecord::Tasks::DatabaseTasks.drop_all

        assert_match "This task only modifies local databases. my-db is on a remote host.",
          $stderr.string
      end
    end

    def test_drops_configurations_with_local_ip
      @configurations[:development]["host"] = "127.0.0.1"

      with_stubbed_configurations do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_drops_configurations_with_local_host
      @configurations[:development]["host"] = "localhost"

      with_stubbed_configurations do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_drops_configurations_with_blank_hosts
      @configurations[:development]["host"] = nil

      with_stubbed_configurations do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    private
      def with_stubbed_configurations
        old_configurations = ActiveRecord::Base.configurations
        ActiveRecord::Base.configurations = @configurations

        yield
      ensure
        ActiveRecord::Base.configurations = old_configurations
      end
  end

  class DatabaseTasksDropCurrentTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "url" => "abstract://prod-db-host/prod-db" }
      }
    end

    def test_drops_current_environment_database
      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [config_for("test", "primary")]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("test")
          )
        end
      end
    end

    def test_drops_current_environment_database_with_url
      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [config_for("production", "primary")]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("production")
          )
        end
      end
    end

    def test_drops_test_and_development_databases_when_env_was_not_specified
      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            [config_for("development", "primary")],
            [config_for("test", "primary")]
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

      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            [config_for("development", "primary")],
            [config_for("test", "primary")]
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

    private
      def config_for(env_name, spec_name)
        ActiveRecord::Base.configurations.configs_for(env_name: env_name, spec_name: spec_name)
      end

      def with_stubbed_configurations
        old_configurations = ActiveRecord::Base.configurations
        ActiveRecord::Base.configurations = @configurations

        yield
      ensure
        ActiveRecord::Base.configurations = old_configurations
      end
  end

  class DatabaseTasksDropCurrentThreeTierTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "primary" => { "database" => "dev-db" }, "secondary" => { "database" => "secondary-dev-db" } },
        "test" => { "primary" => { "database" => "test-db" }, "secondary" => { "database" => "secondary-test-db" } },
        "production" => { "primary" => { "url" => "abstract://prod-db-host/prod-db" }, "secondary" => { "url" => "abstract://secondary-prod-db-host/secondary-prod-db" } }
      }
    end

    def test_drops_current_environment_database
      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            [config_for("test", "primary")],
            [config_for("test", "secondary")]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("test")
          )
        end
      end
    end

    def test_drops_current_environment_database_with_url
      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            [config_for("production", "primary")],
            [config_for("production", "secondary")]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("production")
          )
        end
      end
    end

    def test_drops_test_and_development_databases_when_env_was_not_specified
      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            [config_for("development", "primary")],
            [config_for("development", "secondary")],
            [config_for("test", "primary")],
            [config_for("test", "secondary")]
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

      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :drop,
          [
            [config_for("development", "primary")],
            [config_for("development", "secondary")],
            [config_for("test", "primary")],
            [config_for("test", "secondary")]
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

    private
      def config_for(env_name, spec_name)
        ActiveRecord::Base.configurations.configs_for(env_name: env_name, spec_name: spec_name)
      end

      def with_stubbed_configurations
        old_configurations = ActiveRecord::Base.configurations
        ActiveRecord::Base.configurations = @configurations

        yield
      ensure
        ActiveRecord::Base.configurations = old_configurations
      end
  end

  if current_adapter?(:SQLite3Adapter) && !in_memory_db?
    class DatabaseTasksMigrationTestCase < ActiveRecord::TestCase
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
    end

    class DatabaseTasksMigrateTest < DatabaseTasksMigrationTestCase
      def test_can_migrate_from_pending_migration_error_action_dispatch
        verbose, version = ENV["VERBOSE"], ENV["VERSION"]
        ENV["VERSION"] = "2"
        ENV["VERBOSE"] = "false"

        # run down migration because it was already run on copied db
        assert_empty capture_migration_output

        ENV.delete("VERSION")
        ENV.delete("VERBOSE")

        # re-run up migration
        assert_includes(capture(:stdout) do
          ActiveSupport::ActionableError.dispatch ActiveRecord::PendingMigrationError, "Run pending migrations"
        end, "migrating")
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

    class DatabaseTasksMigrateStatusTest < DatabaseTasksMigrationTestCase
      def test_migrate_status_table
        ActiveRecord::SchemaMigration.create_table
        output = capture_migration_status
        assert_match(/database: :memory:/, output)
        assert_match(/down    001             Valid people have last names/, output)
        assert_match(/down    002             We need reminders/, output)
        assert_match(/down    003             Innocent jointable/, output)
        ActiveRecord::SchemaMigration.drop_table
      end

      private
        def capture_migration_status
          capture(:stdout) do
            ActiveRecord::Tasks::DatabaseTasks.migrate_status
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
          assert_called(eval("@#{v}"), :purge) do
            ActiveRecord::Tasks::DatabaseTasks.purge "adapter" => k
          end
        end
      end
    end
  end

  class DatabaseTasksPurgeCurrentTest < ActiveRecord::TestCase
    def test_purges_current_environment_database
      old_configurations = ActiveRecord::Base.configurations
      configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "database" => "prod-db" }
      }

      ActiveRecord::Base.configurations = configurations

      assert_called_with(
        ActiveRecord::Tasks::DatabaseTasks,
        :purge,
        [ActiveRecord::Base.configurations.configs_for(env_name: "production", spec_name: "primary")]
      ) do
        assert_called_with(ActiveRecord::Base, :establish_connection, [:production]) do
          ActiveRecord::Tasks::DatabaseTasks.purge_current("production")
        end
      end
    ensure
      ActiveRecord::Base.configurations = old_configurations
    end
  end

  class DatabaseTasksPurgeAllTest < ActiveRecord::TestCase
    def test_purge_all_local_configurations
      old_configurations = ActiveRecord::Base.configurations
      configurations = { development: { "database" => "my-db" } }
      ActiveRecord::Base.configurations = configurations

      assert_called_with(
        ActiveRecord::Tasks::DatabaseTasks,
        :purge,
        [ActiveRecord::Base.configurations.configs_for(env_name: "development", spec_name: "primary")]
      ) do
        ActiveRecord::Tasks::DatabaseTasks.purge_all
      end
    ensure
      ActiveRecord::Base.configurations = old_configurations
    end
  end

  unless in_memory_db?
    class DatabaseTasksTruncateAllTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      fixtures :authors, :author_addresses

      def setup
        SchemaMigration.create_table
        SchemaMigration.create!(version: SchemaMigration.table_name)
        InternalMetadata.create_table
        InternalMetadata.create!(key: InternalMetadata.table_name)
      end

      def teardown
        SchemaMigration.delete_all
        InternalMetadata.delete_all
        ActiveRecord::Base.connection_handlers = { writing: ActiveRecord::Base.default_connection_handler }
      end

      def test_truncate_tables
        assert_operator SchemaMigration.count, :>, 0
        assert_operator InternalMetadata.count, :>, 0
        assert_operator Author.count, :>, 0
        assert_operator AuthorAddress.count, :>, 0

        old_configurations = ActiveRecord::Base.configurations
        configurations = { development: ActiveRecord::Base.configurations["arunit"] }
        ActiveRecord::Base.configurations = configurations

        ActiveRecord::Tasks::DatabaseTasks.stub(:root, nil) do
          ActiveRecord::Tasks::DatabaseTasks.truncate_all(
            ActiveSupport::StringInquirer.new("development")
          )
        end

        assert_operator SchemaMigration.count, :>, 0
        assert_operator InternalMetadata.count, :>, 0
        assert_equal 0, Author.count
        assert_equal 0, AuthorAddress.count
      ensure
        ActiveRecord::Base.configurations = old_configurations
      end
    end

    class DatabaseTasksTruncateAllWithPrefixTest < DatabaseTasksTruncateAllTest
      setup do
        ActiveRecord::Base.table_name_prefix = "p_"

        SchemaMigration.reset_table_name
        InternalMetadata.reset_table_name
      end

      teardown do
        ActiveRecord::Base.table_name_prefix = nil

        SchemaMigration.reset_table_name
        InternalMetadata.reset_table_name
      end
    end

    class DatabaseTasksTruncateAllWithSuffixTest < DatabaseTasksTruncateAllTest
      setup do
        ActiveRecord::Base.table_name_suffix = "_s"

        SchemaMigration.reset_table_name
        InternalMetadata.reset_table_name
      end

      teardown do
        ActiveRecord::Base.table_name_suffix = nil

        SchemaMigration.reset_table_name
        InternalMetadata.reset_table_name
      end
    end
  end

  class DatabaseTasksTruncateAllWithMultipleDatabasesTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "primary" => { "database" => "dev-db" }, "secondary" => { "database" => "secondary-dev-db" } },
        "test" => { "primary" => { "database" => "test-db" }, "secondary" => { "database" => "secondary-test-db" } },
        "production" => { "primary" => { "url" => "abstract://prod-db-host/prod-db" }, "secondary" => { "url" => "abstract://secondary-prod-db-host/secondary-prod-db" } }
      }
    end

    def test_truncate_all_databases_for_environment
      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :truncate_tables,
          [
            [config_for("test", "primary")],
            [config_for("test", "secondary")]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.truncate_all(
            ActiveSupport::StringInquirer.new("test")
          )
        end
      end
    end

    def test_truncate_all_databases_with_url_for_environment
      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :truncate_tables,
          [
            [config_for("production", "primary")],
            [config_for("production", "secondary")]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.truncate_all(
            ActiveSupport::StringInquirer.new("production")
          )
        end
      end
    end

    def test_truncate_all_development_databases_when_env_is_not_specified
      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :truncate_tables,
          [
            [config_for("development", "primary")],
            [config_for("development", "secondary")]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.truncate_all(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    end

    def test_truncate_all_development_databases_when_env_is_development
      old_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "development"

      with_stubbed_configurations do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :truncate_tables,
          [
            [config_for("development", "primary")],
            [config_for("development", "secondary")]
          ]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.truncate_all(
            ActiveSupport::StringInquirer.new("development")
          )
        end
      end
    ensure
      ENV["RAILS_ENV"] = old_env
    end

    private
      def config_for(env_name, spec_name)
        ActiveRecord::Base.configurations.configs_for(env_name: env_name, spec_name: spec_name)
      end

      def with_stubbed_configurations
        old_configurations = ActiveRecord::Base.configurations
        ActiveRecord::Base.configurations = @configurations

        yield
      ensure
        ActiveRecord::Base.configurations = old_configurations
      end
  end

  class DatabaseTasksCharsetTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_charset") do
        with_stubbed_new do
          assert_called(eval("@#{v}"), :charset) do
            ActiveRecord::Tasks::DatabaseTasks.charset "adapter" => k
          end
        end
      end
    end

    def test_charset_current
      old_configurations = ActiveRecord::Base.configurations
      configurations = {
        "production"  => { "database" => "prod-db" }
      }

      ActiveRecord::Base.configurations = configurations

      assert_called_with(
        ActiveRecord::Tasks::DatabaseTasks,
        :charset,
        [ActiveRecord::Base.configurations.configs_for(env_name: "production", spec_name: "primary")]
      ) do
        ActiveRecord::Tasks::DatabaseTasks.charset_current("production", "primary")
      end
    ensure
      ActiveRecord::Base.configurations = old_configurations
    end
  end

  class DatabaseTasksCollationTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_collation") do
        with_stubbed_new do
          assert_called(eval("@#{v}"), :collation) do
            ActiveRecord::Tasks::DatabaseTasks.collation "adapter" => k
          end
        end
      end
    end

    def test_collation_current
      old_configurations = ActiveRecord::Base.configurations
      configurations = {
        "production"  => { "database" => "prod-db" }
      }

      ActiveRecord::Base.configurations = configurations

      assert_called_with(
        ActiveRecord::Tasks::DatabaseTasks,
        :collation,
        [ActiveRecord::Base.configurations.configs_for(env_name: "production", spec_name: "primary")]
      ) do
        ActiveRecord::Tasks::DatabaseTasks.collation_current("production", "primary")
      end
    ensure
      ActiveRecord::Base.configurations = old_configurations
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
          assert_called_with(
            eval("@#{v}"), :structure_dump,
            ["awesome-file.sql", nil]
          ) do
            ActiveRecord::Tasks::DatabaseTasks.structure_dump({ "adapter" => k }, "awesome-file.sql")
          end
        end
      end
    end
  end

  class DatabaseTasksStructureLoadTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_structure_load") do
        with_stubbed_new do
          assert_called_with(
            eval("@#{v}"),
            :structure_load,
            ["awesome-file.sql", nil]
          ) do
            ActiveRecord::Tasks::DatabaseTasks.structure_load({ "adapter" => k }, "awesome-file.sql")
          end
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
