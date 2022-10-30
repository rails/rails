# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    if current_adapter?(:SQLite3Adapter) && !in_memory_db?
      class PendingMigrationsTest < ActiveRecord::TestCase
        self.use_transactional_tests = false

        setup do
          @tmp_dir = Dir.mktmpdir("pending_migrations_test-")

          @original_configurations = ActiveRecord::Base.configurations
          ActiveRecord::Base.configurations = base_config
          ActiveRecord::Base.establish_connection(:primary)

          @app = Minitest::Mock.new
        end

        teardown do
          ActiveRecord::Base.configurations = @original_configurations
          ActiveRecord::Base.establish_connection(:arunit)
          FileUtils.rm_rf(@tmp_dir)
        end

        def run_migrations
          migrator = Base.connection.migration_context
          capture(:stdout) { migrator.migrate }
        end

        def create_migration(number, name, database: :primary)
          migration_dir = migrations_path_for(database)
          FileUtils.mkdir_p(migration_dir)

          filename = "#{number}_#{name.underscore}.rb"
          File.write(File.join(migration_dir, filename), <<~RUBY)
            class #{name.classify} < ActiveRecord::Migration::Current
            end
          RUBY
        end

        def test_errors_if_pending
          create_migration "01", "create_foo"

          assert_raises ActiveRecord::PendingMigrationError do
            CheckPending.new(@app).call({})
          end

          # Continues failing
          assert_raises ActiveRecord::PendingMigrationError do
            CheckPending.new(@app).call({})
          end
        end

        def test_checks_if_supported
          run_migrations

          check_pending = CheckPending.new(@app)

          @app.expect :call, nil, [{}]
          check_pending.call({})
          @app.verify

          # With cached result
          @app.expect :call, nil, [{}]
          check_pending.call({})
          @app.verify
        end

        def test_okay_with_no_migrations
          check_pending = CheckPending.new(@app)

          @app.expect :call, nil, [{}]
          check_pending.call({})
          @app.verify

          # With cached result
          @app.expect :call, nil, [{}]
          check_pending.call({})
          @app.verify
        end

        # Regression test for https://github.com/rails/rails/pull/29759
        def test_understands_migrations_created_out_of_order
          # With a prior file before even initialization
          create_migration "05", "create_bar"
          quietly { run_migrations }

          check_pending = CheckPending.new(@app)

          @app.expect :call, nil, [{}]
          check_pending.call({})
          @app.verify

          # It understands the new migration created at 01
          create_migration "01", "create_foo"
          assert_raises ActiveRecord::PendingMigrationError do
            check_pending.call({})
          end
        end

        def test_with_multiple_database
          create_migration "01", "create_bar", database: :secondary

          assert_raises ActiveRecord::PendingMigrationError do
            CheckPending.new(@app).call({})
          end

          ActiveRecord::Base.establish_connection(:secondary)
          quietly { run_migrations }

          ActiveRecord::Base.establish_connection(:primary)

          @app.expect :call, nil, [{}]
          CheckPending.new(@app).call({})
          @app.verify

          # Now check exclusion if database_tasks is set to false for the db_config
          create_migration "02", "create_foo", database: :secondary
          assert_raises ActiveRecord::PendingMigrationError do
            CheckPending.new(@app).call({})
          end

          new_config = base_config
          new_config[ActiveRecord::ConnectionHandling::DEFAULT_ENV.call][:secondary][:database_tasks] = false
          ActiveRecord::Base.configurations = new_config

          @app.expect :call, nil, [{}]
          CheckPending.new(@app).call({})
          @app.verify
        end

        def test_with_stdlib_logger
          old, ActiveRecord::Base.logger = ActiveRecord::Base.logger, ::Logger.new($stdout)
          quietly do
            assert_nothing_raised { ActiveRecord::Migration::CheckPending.new(Proc.new { }).call({}) }
          end
        ensure
          ActiveRecord::Base.logger = old
        end

        private
          def database_path_for(database_name)
            File.join(@tmp_dir, "#{database_name}.sqlite3")
          end

          def migrations_path_for(database_name)
            File.join(@tmp_dir, "#{database_name}-migrations")
          end

          def base_config
            {
              ActiveRecord::ConnectionHandling::DEFAULT_ENV.call => {
                primary: {
                  adapter: "sqlite3",
                  database: database_path_for(:primary),
                  migrations_paths: migrations_path_for(:primary),
                },
                secondary: {
                  adapter: "sqlite3",
                  database: database_path_for(:secondary),
                  migrations_paths: migrations_path_for(:secondary),
                }
              }
            }
          end
      end
    end
  end
end
