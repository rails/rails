# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    class PendingMigrationsTest < ActiveRecord::TestCase
      def setup
        super
        @migration_dir = Dir.mktmpdir("activerecord-migrations-")
        @original_migrations_paths = ActiveRecord::Migrator.migrations_paths
        ActiveRecord::Migrator.migrations_paths = [@migration_dir]
        @connection = Minitest::Mock.new
        @app = Minitest::Mock.new
        conn = @connection
        @pending_class = Class.new(CheckPending) {
          define_method(:connection) { conn }
        }
      end

      def teardown
        FileUtils.rm_rf(@migration_dir)
        assert @connection.verify
        assert @app.verify
        super
      end

      def test_errors_if_pending
        @pending = @pending_class.new(@app)
        ActiveRecord::Migrator.stub :needs_migration?, true do
          assert_raise ActiveRecord::PendingMigrationError do
            @pending.call(nil)
          end
        end
      end

      def test_checks_if_supported
        @pending = @pending_class.new(@app)
        @app.expect :call, nil, [:foo]

        ActiveRecord::Migrator.expects(:needs_migration?).returns(false)
        @pending.call(:foo)
      end

      def test_does_not_recheck_if_nothing_changed
        @pending = @pending_class.new(@app)
        @app.expect :call, nil, [:foo]
        @app.expect :call, nil, [:foo2]

        ActiveRecord::Migrator.expects(:needs_migration?).returns(false)
        @pending.call(:foo)

        # Second call should not re-check migrations
        @pending.call(:foo2)
      end

      def test_rechecks_when_file_created_or_updated2
        @pending = @pending_class.new(@app)
        @app.expect :call, nil, [:foo]
        @app.expect :call, nil, [:foo2]
        @app.expect :call, nil, [:foo3]
        @app.expect :call, nil, [:foo4]

        # Must check first time
        ActiveRecord::Migrator.expects(:needs_migration?).returns(false)
        @pending.call(:foo)

        # Must re-check
        ActiveRecord::Migrator.expects(:needs_migration?).returns(false)
        FileUtils.touch(File.join(@migration_dir, "01_foobar.rb"), mtime: Time.now - 100)
        @pending.call(:foo2)

        # Nothing changed. No check
        ActiveRecord::Migrator.expects(:needs_migration?).never
        @pending.call(:foo3)

        # File updated. Must re-check
        ActiveRecord::Migrator.expects(:needs_migration?).returns(false)
        FileUtils.touch(File.join(@migration_dir, "01_foobar.rb"))
        @pending.call(:foo4)
      end

      # Regression test for https://github.com/rails/rails/pull/29759
      def test_understands_migrations_created_out_of_order
        # With a prior file before even initialization
        FileUtils.touch(File.join(@migration_dir, "05_baz.rb"))

        @pending = @pending_class.new(@app)
        @app.expect :call, nil, [:foo]

        # And no necessary migrations on our first check
        ActiveRecord::Migrator.expects(:needs_migration?).returns(false)
        @pending.call(:foo)

        # It understands the new migration created at 01
        FileUtils.touch(File.join(@migration_dir, "01_foobar.rb"))
        ActiveRecord::Migrator.expects(:needs_migration?).returns(true)
        assert_raise ActiveRecord::PendingMigrationError do
          @pending.call(:foo2)
        end
      end

      def test_continues_raising_until_fixed
        @pending = @pending_class.new(@app)
        @app.expect :call, nil, [:foo3]

        ActiveRecord::Migrator.expects(:needs_migration?).returns(true)
        assert_raise ActiveRecord::PendingMigrationError do
          @pending.call(:foo)
        end

        # Second call should re-check migrations, continue raising
        ActiveRecord::Migrator.expects(:needs_migration?).returns(true)
        assert_raise ActiveRecord::PendingMigrationError do
          @pending.call(:foo2)
        end

        # Finally we re-check, pass, and continue to the app
        ActiveRecord::Migrator.expects(:needs_migration?).returns(false)
        @pending.call(:foo3)
      end
    end
  end
end
