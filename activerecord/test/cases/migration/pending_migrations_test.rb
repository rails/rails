# frozen_string_literal: true

require 'cases/helper'

module ActiveRecord
  class Migration
    if current_adapter?(:SQLite3Adapter) && !in_memory_db?
      class PendingMigrationsTest < ActiveRecord::TestCase
        setup do
          @migration_dir = Dir.mktmpdir('activerecord-migrations-')

          file = ActiveRecord::Base.connection.raw_connection.filename
          @conn = ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:', migrations_paths: @migration_dir
          source_db = SQLite3::Database.new file
          dest_db = ActiveRecord::Base.connection.raw_connection
          backup = SQLite3::Backup.new(dest_db, 'main', source_db, 'main')
          backup.step(-1)
          backup.finish

          ActiveRecord::Base.connection.drop_table 'schema_migrations', if_exists: true

          @app = Minitest::Mock.new
        end

        teardown do
          @conn.release_connection if @conn
          ActiveRecord::Base.establish_connection :arunit
          FileUtils.rm_rf(@migration_dir)
        end

        def run_migrations
          migrator = Base.connection.migration_context
          capture(:stdout) { migrator.migrate }
        end

        def create_migration(number, name)
          filename = "#{number}_#{name.underscore}.rb"
          File.write(File.join(@migration_dir, filename), <<~RUBY)
            class #{name.classify} < ActiveRecord::Migration::Current
            end
          RUBY
        end

        def test_errors_if_pending
          create_migration '01', 'create_foo'

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
          create_migration '05', 'create_bar'
          run_migrations

          check_pending = CheckPending.new(@app)

          @app.expect :call, nil, [{}]
          check_pending.call({})
          @app.verify

          # It understands the new migration created at 01
          create_migration '01', 'create_foo'
          assert_raises ActiveRecord::PendingMigrationError do
            check_pending.call({})
          end
        end
      end
    end
  end
end
