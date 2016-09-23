require "cases/helper"
require "active_record/tasks/database_tasks"

module ActiveRecord
  module DatabaseTasksSetupper
    def setup
      @mysql_tasks, @postgresql_tasks, @sqlite_tasks = stub, stub, stub
      ActiveRecord::Tasks::MySQLDatabaseTasks.stubs(:new).returns @mysql_tasks
      ActiveRecord::Tasks::PostgreSQLDatabaseTasks.stubs(:new).returns @postgresql_tasks
      ActiveRecord::Tasks::SQLiteDatabaseTasks.stubs(:new).returns @sqlite_tasks

      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
    end
  end

  ADAPTERS_TASKS = {
    mysql2:     :mysql_tasks,
    postgresql: :postgresql_tasks,
    sqlite3:    :sqlite_tasks
  }

  class DatabaseTasksUtilsTask< ActiveRecord::TestCase
    def test_raises_an_error_when_called_with_protected_environment
      ActiveRecord::Migrator.stubs(:current_version).returns(1)

      protected_environments = ActiveRecord::Base.protected_environments.dup
      current_env            = ActiveRecord::Migrator.current_environment
      assert_not_includes protected_environments, current_env
      # Assert no error
      ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!

      ActiveRecord::Base.protected_environments << current_env
      assert_raise(ActiveRecord::ProtectedEnvironmentError) do
        ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
      end
    ensure
      ActiveRecord::Base.protected_environments = protected_environments
    end

    def test_raises_an_error_if_no_migrations_have_been_made
      ActiveRecord::InternalMetadata.stubs(:table_exists?).returns(false)
      ActiveRecord::Migrator.stubs(:current_version).returns(1)

      assert_raise(ActiveRecord::NoEnvironmentInSchemaError) do
        ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
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

      klazz.stubs(:new).returns instance
      instance.expects(:structure_dump).with("awesome-file.sql")

      ActiveRecord::Tasks::DatabaseTasks.register_task(/foo/, klazz)
      ActiveRecord::Tasks::DatabaseTasks.structure_dump({ "adapter" => :foo }, "awesome-file.sql")
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
        eval("@#{v}").expects(:create)
        ActiveRecord::Tasks::DatabaseTasks.create "adapter" => k
      end
    end
  end

  class DatabaseTasksCreateAllTest < ActiveRecord::TestCase
    def setup
      @configurations = { "development" => { "database" => "my-db" } }

      ActiveRecord::Base.stubs(:configurations).returns(@configurations)
    end

    def test_ignores_configurations_without_databases
      @configurations["development"].merge!("database" => nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:create).never

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_ignores_remote_databases
      @configurations["development"].merge!("host" => "my.server.tld")
      $stderr.stubs(:puts).returns(nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:create).never

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_warning_for_remote_databases
      @configurations["development"].merge!("host" => "my.server.tld")

      $stderr.expects(:puts).with("This task only modifies local databases. my-db is on a remote host.")

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_creates_configurations_with_local_ip
      @configurations["development"].merge!("host" => "127.0.0.1")

      ActiveRecord::Tasks::DatabaseTasks.expects(:create)

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_creates_configurations_with_local_host
      @configurations["development"].merge!("host" => "localhost")

      ActiveRecord::Tasks::DatabaseTasks.expects(:create)

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end

    def test_creates_configurations_with_blank_hosts
      @configurations["development"].merge!("host" => nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:create)

      ActiveRecord::Tasks::DatabaseTasks.create_all
    end
  end

  class DatabaseTasksCreateCurrentTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "database" => "prod-db" }
      }

      ActiveRecord::Base.stubs(:configurations).returns(@configurations)
      ActiveRecord::Base.stubs(:establish_connection).returns(true)
    end

    def test_creates_current_environment_database
      ActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with("database" => "prod-db")

      ActiveRecord::Tasks::DatabaseTasks.create_current(
        ActiveSupport::StringInquirer.new("production")
      )
    end

    def test_creates_test_and_development_databases_when_env_was_not_specified
      ActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with("database" => "dev-db")
      ActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with("database" => "test-db")

      ActiveRecord::Tasks::DatabaseTasks.create_current(
        ActiveSupport::StringInquirer.new("development")
      )
    end

    def test_creates_test_and_development_databases_when_rails_env_is_development
      old_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "development"
      ActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with("database" => "dev-db")
      ActiveRecord::Tasks::DatabaseTasks.expects(:create).
        with("database" => "test-db")

      ActiveRecord::Tasks::DatabaseTasks.create_current(
        ActiveSupport::StringInquirer.new("development")
      )
    ensure
      ENV["RAILS_ENV"] = old_env
    end

    def test_establishes_connection_for_the_given_environment
      ActiveRecord::Tasks::DatabaseTasks.stubs(:create).returns true

      ActiveRecord::Base.expects(:establish_connection).with(:development)

      ActiveRecord::Tasks::DatabaseTasks.create_current(
        ActiveSupport::StringInquirer.new("development")
      )
    end
  end

  class DatabaseTasksDropTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_drop") do
        eval("@#{v}").expects(:drop)
        ActiveRecord::Tasks::DatabaseTasks.drop "adapter" => k
      end
    end
  end

  class DatabaseTasksDropAllTest < ActiveRecord::TestCase
    def setup
      @configurations = { development: { "database" => "my-db" } }

      ActiveRecord::Base.stubs(:configurations).returns(@configurations)
    end

    def test_ignores_configurations_without_databases
      @configurations[:development].merge!("database" => nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).never

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_ignores_remote_databases
      @configurations[:development].merge!("host" => "my.server.tld")
      $stderr.stubs(:puts).returns(nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).never

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_warning_for_remote_databases
      @configurations[:development].merge!("host" => "my.server.tld")

      $stderr.expects(:puts).with("This task only modifies local databases. my-db is on a remote host.")

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_drops_configurations_with_local_ip
      @configurations[:development].merge!("host" => "127.0.0.1")

      ActiveRecord::Tasks::DatabaseTasks.expects(:drop)

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_drops_configurations_with_local_host
      @configurations[:development].merge!("host" => "localhost")

      ActiveRecord::Tasks::DatabaseTasks.expects(:drop)

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    def test_drops_configurations_with_blank_hosts
      @configurations[:development].merge!("host" => nil)

      ActiveRecord::Tasks::DatabaseTasks.expects(:drop)

      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end
  end

  class DatabaseTasksDropCurrentTest < ActiveRecord::TestCase
    def setup
      @configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "database" => "prod-db" }
      }

      ActiveRecord::Base.stubs(:configurations).returns(@configurations)
    end

    def test_drops_current_environment_database
      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with("database" => "prod-db")

      ActiveRecord::Tasks::DatabaseTasks.drop_current(
        ActiveSupport::StringInquirer.new("production")
      )
    end

    def test_drops_test_and_development_databases_when_env_was_not_specified
      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with("database" => "dev-db")
      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with("database" => "test-db")

      ActiveRecord::Tasks::DatabaseTasks.drop_current(
        ActiveSupport::StringInquirer.new("development")
      )
    end

    def test_drops_testand_development_databases_when_rails_env_is_development
      old_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "development"
      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with("database" => "dev-db")
      ActiveRecord::Tasks::DatabaseTasks.expects(:drop).
        with("database" => "test-db")

      ActiveRecord::Tasks::DatabaseTasks.drop_current(
        ActiveSupport::StringInquirer.new("development")
      )
    ensure
      ENV["RAILS_ENV"] = old_env
    end
  end

  class DatabaseTasksMigrateTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    def setup
      ActiveRecord::Tasks::DatabaseTasks.migrations_paths = "custom/path"
    end

    def teardown
      ActiveRecord::Tasks::DatabaseTasks.migrations_paths = nil
    end

    def test_migrate_receives_correct_env_vars
      verbose, version = ENV["VERBOSE"], ENV["VERSION"]

      ENV["VERBOSE"] = "false"
      ENV["VERSION"] = "4"

      ActiveRecord::Migrator.expects(:migrate).with("custom/path", 4)
      ActiveRecord::Tasks::DatabaseTasks.migrate
    ensure
      ENV["VERBOSE"], ENV["VERSION"] = verbose, version
    end

    def test_migrate_clears_schema_cache_afterward
      ActiveRecord::Base.expects(:clear_cache!)
      ActiveRecord::Tasks::DatabaseTasks.migrate
    end
  end

  class DatabaseTasksPurgeTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_purge") do
        eval("@#{v}").expects(:purge)
        ActiveRecord::Tasks::DatabaseTasks.purge "adapter" => k
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
      ActiveRecord::Base.stubs(:configurations).returns(configurations)

      ActiveRecord::Tasks::DatabaseTasks.expects(:purge).
        with("database" => "prod-db")
      ActiveRecord::Base.expects(:establish_connection).with(:production)

      ActiveRecord::Tasks::DatabaseTasks.purge_current("production")
    end
  end

  class DatabaseTasksPurgeAllTest < ActiveRecord::TestCase
    def test_purge_all_local_configurations
      configurations = { development: { "database" => "my-db" } }
      ActiveRecord::Base.stubs(:configurations).returns(configurations)

      ActiveRecord::Tasks::DatabaseTasks.expects(:purge).
        with("database" => "my-db")

      ActiveRecord::Tasks::DatabaseTasks.purge_all
    end
  end

  class DatabaseTasksCharsetTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_charset") do
        eval("@#{v}").expects(:charset)
        ActiveRecord::Tasks::DatabaseTasks.charset "adapter" => k
      end
    end
  end

  class DatabaseTasksCollationTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_collation") do
        eval("@#{v}").expects(:collation)
        ActiveRecord::Tasks::DatabaseTasks.collation "adapter" => k
      end
    end
  end

  class DatabaseTasksStructureDumpTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_structure_dump") do
        eval("@#{v}").expects(:structure_dump).with("awesome-file.sql")
        ActiveRecord::Tasks::DatabaseTasks.structure_dump({ "adapter" => k }, "awesome-file.sql")
      end
    end
  end

  class DatabaseTasksStructureLoadTest < ActiveRecord::TestCase
    include DatabaseTasksSetupper

    ADAPTERS_TASKS.each do |k, v|
      define_method("test_#{k}_structure_load") do
        eval("@#{v}").expects(:structure_load).with("awesome-file.sql")
        ActiveRecord::Tasks::DatabaseTasks.structure_load({ "adapter" => k }, "awesome-file.sql")
      end
    end
  end

  class DatabaseTasksCheckSchemaFileTest < ActiveRecord::TestCase
    def test_check_schema_file
      Kernel.expects(:abort).with(regexp_matches(/awesome-file.sql/))
      ActiveRecord::Tasks::DatabaseTasks.check_schema_file("awesome-file.sql")
    end
  end

  class DatabaseTasksCheckSchemaFileDefaultsTest < ActiveRecord::TestCase
    def test_check_schema_file_defaults
      ActiveRecord::Tasks::DatabaseTasks.stubs(:db_dir).returns("/tmp")
      assert_equal "/tmp/schema.rb", ActiveRecord::Tasks::DatabaseTasks.schema_file
    end
  end

  class DatabaseTasksCheckSchemaFileSpecifiedFormatsTest < ActiveRecord::TestCase
    { ruby: "schema.rb", sql: "structure.sql" }.each_pair do |fmt, filename|
      define_method("test_check_schema_file_for_#{fmt}_format") do
        ActiveRecord::Tasks::DatabaseTasks.stubs(:db_dir).returns("/tmp")
        assert_equal "/tmp/#{filename}", ActiveRecord::Tasks::DatabaseTasks.schema_file(fmt)
      end
    end
  end
end
