# frozen_string_literal: true

require "cases/helper"
require "active_record/tasks/database_tasks"

module ActiveRecord
  class LegacyDatabaseTasksCreateAllTest < ActiveRecord::TestCase
    def setup
      @old_configurations = ActiveRecord::Base.configurations.to_h

      @configurations = { "development" => { "database" => "my-db" } }

      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr

      ActiveRecord::Base.configurations = @configurations
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
      ActiveRecord::Base.configurations = @old_configurations
    end

    def test_ignores_configurations_without_databases
      @configurations["development"]["database"] = nil

      ActiveRecord::Base.configurations.to_h do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_ignores_remote_databases
      @configurations["development"]["host"] = "my.server.tld"

      ActiveRecord::Base.configurations.to_h do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_warning_for_remote_databases
      @configurations["development"]["host"] = "my.server.tld"

      ActiveRecord::Base.configurations.to_h do
        ActiveRecord::Tasks::DatabaseTasks.create_all

        assert_match "This task only modifies local databases. my-db is on a remote host.",
          $stderr.string
      end
    end

    def test_creates_configurations_with_local_ip
      @configurations["development"]["host"] = "127.0.0.1"

      ActiveRecord::Base.configurations.to_h do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_creates_configurations_with_local_host
      @configurations["development"]["host"] = "localhost"

      ActiveRecord::Base.configurations.to_h do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end

    def test_creates_configurations_with_blank_hosts
      @configurations["development"]["host"] = nil

      ActiveRecord::Base.configurations.to_h do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :create) do
          ActiveRecord::Tasks::DatabaseTasks.create_all
        end
      end
    end
  end

  class LegacyDatabaseTasksCreateCurrentTest < ActiveRecord::TestCase
    def setup
      @old_configurations = ActiveRecord::Base.configurations.to_h

      @configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "url" => "abstract://prod-db-url" }
      }

      ActiveRecord::Base.configurations = @configurations
    end

    def teardown
      ActiveRecord::Base.configurations = @old_configurations
    end

    def test_creates_current_environment_database
      ActiveRecord::Base.configurations.to_h do
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
      ActiveRecord::Base.configurations.to_h do
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
      ActiveRecord::Base.configurations.to_h do
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

      ActiveRecord::Base.configurations.to_h do
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
  end

  class LegacyDatabaseTasksCreateCurrentThreeTierTest < ActiveRecord::TestCase
    def setup
      @old_configurations = ActiveRecord::Base.configurations.to_h

      @configurations = {
        "development" => { "primary" => { "database" => "dev-db" }, "secondary" => { "database" => "secondary-dev-db" } },
        "test" => { "primary" => { "database" => "test-db" }, "secondary" => { "database" => "secondary-test-db" } },
        "production" => { "primary" => { "url" => "abstract://prod-db-url" }, "secondary" => { "url" => "abstract://secondary-prod-db-url" } }
      }

      ActiveRecord::Base.configurations = @configurations
    end

    def teardown
      ActiveRecord::Base.configurations = @old_configurations
    end

    def test_creates_current_environment_database
      ActiveRecord::Base.configurations.to_h do
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
      ActiveRecord::Base.configurations.to_h do
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
      ActiveRecord::Base.configurations.to_h do
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

      ActiveRecord::Base.configurations.to_h do
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
  end

  class LegacyDatabaseTasksDropAllTest < ActiveRecord::TestCase
    def setup
      @old_configurations = ActiveRecord::Base.configurations.to_h

      @configurations = { development: { "database" => "my-db" } }

      $stdout, @original_stdout = StringIO.new, $stdout
      $stderr, @original_stderr = StringIO.new, $stderr

      ActiveRecord::Base.configurations = @configurations
    end

    def teardown
      $stdout, $stderr = @original_stdout, @original_stderr
      ActiveRecord::Base.configurations = @old_configurations
    end

    def test_ignores_configurations_without_databases
      @configurations[:development]["database"] = nil

      ActiveRecord::Base.configurations.to_h do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_ignores_remote_databases
      @configurations[:development]["host"] = "my.server.tld"

      ActiveRecord::Base.configurations.to_h do
        assert_not_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_warning_for_remote_databases
      @configurations[:development]["host"] = "my.server.tld"

      ActiveRecord::Base.configurations.to_h do
        ActiveRecord::Tasks::DatabaseTasks.drop_all

        assert_match "This task only modifies local databases. my-db is on a remote host.",
          $stderr.string
      end
    end

    def test_drops_configurations_with_local_ip
      @configurations[:development]["host"] = "127.0.0.1"

      ActiveRecord::Base.configurations.to_h do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_drops_configurations_with_local_host
      @configurations[:development]["host"] = "localhost"

      ActiveRecord::Base.configurations.to_h do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end

    def test_drops_configurations_with_blank_hosts
      @configurations[:development]["host"] = nil

      ActiveRecord::Base.configurations.to_h do
        assert_called(ActiveRecord::Tasks::DatabaseTasks, :drop) do
          ActiveRecord::Tasks::DatabaseTasks.drop_all
        end
      end
    end
  end

  class LegacyDatabaseTasksDropCurrentTest < ActiveRecord::TestCase
    def setup
      @old_configurations = ActiveRecord::Base.configurations.to_h

      @configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "url" => "abstract://prod-db-url" }
      }

      ActiveRecord::Base.configurations = @configurations
    end

    def teardown
      ActiveRecord::Base.configurations = @old_configurations
    end

    def test_drops_current_environment_database
      ActiveRecord::Base.configurations.to_h do
        assert_called_with(ActiveRecord::Tasks::DatabaseTasks, :drop,
                           ["database" => "test-db"]) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("test")
          )
        end
      end
    end

    def test_drops_current_environment_database_with_url
      ActiveRecord::Base.configurations.to_h do
        assert_called_with(ActiveRecord::Tasks::DatabaseTasks, :drop,
                           ["url" => "prod-db-url"]) do
          ActiveRecord::Tasks::DatabaseTasks.drop_current(
            ActiveSupport::StringInquirer.new("production")
          )
        end
      end
    end

    def test_drops_test_and_development_databases_when_env_was_not_specified
      ActiveRecord::Base.configurations.to_h do
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

      ActiveRecord::Base.configurations.to_h do
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

  class LegacyDatabaseTasksDropCurrentThreeTierTest < ActiveRecord::TestCase
    def setup
      @old_configurations = ActiveRecord::Base.configurations.to_h

      @configurations = {
        "development" => { "primary" => { "database" => "dev-db" }, "secondary" => { "database" => "secondary-dev-db" } },
        "test" => { "primary" => { "database" => "test-db" }, "secondary" => { "database" => "secondary-test-db" } },
        "production" => { "primary" => { "url" => "abstract://prod-db-url" }, "secondary" => { "url" => "abstract://secondary-prod-db-url" } }
      }

      ActiveRecord::Base.configurations = @configurations
    end

    def teardown
      ActiveRecord::Base.configurations = @old_configurations
    end

    def test_drops_current_environment_database
      ActiveRecord::Base.configurations.to_h do
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
      ActiveRecord::Base.configurations.to_h do
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
      ActiveRecord::Base.configurations.to_h do
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

      ActiveRecord::Base.configurations.to_h do
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

  class LegacyDatabaseTasksPurgeCurrentTest < ActiveRecord::TestCase
    def test_purges_current_environment_database
      @old_configurations = ActiveRecord::Base.configurations.to_h

      configurations = {
        "development" => { "database" => "dev-db" },
        "test"        => { "database" => "test-db" },
        "production"  => { "database" => "prod-db" }
      }

      ActiveRecord::Base.configurations = configurations

      ActiveRecord::Base.configurations.to_h do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :purge,
          ["database" => "prod-db"]
        ) do
          assert_called_with(ActiveRecord::Base, :establish_connection, [:production]) do
            ActiveRecord::Tasks::DatabaseTasks.purge_current("production")
          end
        end
      end
    ensure
      ActiveRecord::Base.configurations = @old_configurations
    end
  end

  class LegacyDatabaseTasksPurgeAllTest < ActiveRecord::TestCase
    def test_purge_all_local_configurations
      @old_configurations = ActiveRecord::Base.configurations.to_h

      configurations = { development: { "database" => "my-db" } }
      ActiveRecord::Base.configurations = configurations

      ActiveRecord::Base.configurations.to_h do
        assert_called_with(
          ActiveRecord::Tasks::DatabaseTasks,
          :purge,
          ["database" => "my-db"]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.purge_all
        end
      end
    ensure
      ActiveRecord::Base.configurations = @old_configurations
    end
  end
end
