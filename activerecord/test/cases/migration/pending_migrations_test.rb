# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/hash/deep_merge"

module ActiveRecord
  class Migration
    class PendingMigrationsTest < ActiveRecord::TestCase
      if current_adapter?(:SQLite3Adapter) && !in_memory_db?
        self.use_transactional_tests = false

        setup do
          @tmp_dir = Dir.mktmpdir("pending_migrations_test-")

          @original_configurations = ActiveRecord::Base.configurations
          ActiveRecord::Base.configurations = base_config
          ActiveRecord::Base.establish_connection(:primary)
        end

        teardown do
          ActiveRecord::Base.configurations = @original_configurations
          ActiveRecord::Base.establish_connection(:arunit)
          FileUtils.rm_rf(@tmp_dir)
        end

        def run_migrations
          migrator = Base.connection_pool.migration_context
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
          assert_pending_migrations("01_create_foo.rb")
        end

        def test_checks_if_supported
          run_migrations
          assert_no_pending_migrations
        end

        def test_okay_with_no_migrations
          assert_no_pending_migrations
        end

        # Regression test for https://github.com/rails/rails/pull/29759
        def test_understands_migrations_created_out_of_order
          # With a prior file before even initialization
          create_migration "05", "create_bar"
          quietly { run_migrations }
          assert_no_pending_migrations

          # It understands the new migration created at 01
          create_migration "01", "create_foo"
          assert_pending_migrations("01_create_foo.rb")
        end

        def test_with_multiple_database
          create_migration "01", "create_bar", database: :primary
          create_migration "02", "create_foo", database: :secondary
          assert_pending_migrations("01_create_bar.rb", "02_create_foo.rb")

          ActiveRecord::Base.establish_connection(:secondary)
          quietly { run_migrations }

          ActiveRecord::Base.establish_connection(:primary)
          quietly { run_migrations }

          assert_no_pending_migrations
        end

        def test_with_stdlib_logger
          old, ActiveRecord::Base.logger = ActiveRecord::Base.logger, ::Logger.new(StringIO.new)
          assert_nothing_raised { CheckPending.new(proc { }).call({}) }
        ensure
          ActiveRecord::Base.logger = old
        end

        private
          def assert_pending_migrations(*expected_migrations)
            2.times do
              assert_raises ActiveRecord::PendingMigrationError do
                ActiveRecord::Migration.check_all_pending!
              end

              error = assert_raises ActiveRecord::PendingMigrationError do
                CheckPending.new(proc { flunk }).call({})
              end

              assert_includes error.message, "Migrations are pending."
              expected_migrations.each do |migration|
                assert_includes error.message, migration
              end
            end
          end

          def assert_no_pending_migrations
            app = Minitest::Mock.new
            check_pending = CheckPending.new(app)

            2.times do
              assert_nothing_raised do
                ActiveRecord::Migration.check_all_pending!
              end

              app.expect :call, nil, [{}]
              check_pending.call({})
              app.verify
            end
          end

          def database_path_for(database_name)
            File.join(@tmp_dir, "#{database_name}.sqlite3")
          end

          def migrations_path_for(database_name)
            File.join(@tmp_dir, "#{database_name}-migrations")
          end

          def base_config(additional_config = {})
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
                },
              }.deep_merge(additional_config)
            }
          end
      end
    end
  end
end
