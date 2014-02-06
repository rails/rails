require 'cases/helper'
require "minitest/mock"

module ActiveRecord
  class Migration
    class PendingMigrationsTest < ActiveRecord::TestCase
      def setup
        super
        @connection = MiniTest::Mock.new
        @app = MiniTest::Mock.new
        @pending = CheckPending.new(@app, @connection)
        @pending.instance_variable_set :@last_check, -1 # Force checking
      end

      def teardown
        super
        assert @connection.verify
        assert @app.verify
      end

      def test_errors_if_pending
        @connection.expect :supports_migrations?, true

        ActiveRecord::Migrator.stub :needs_migration?, true do
          assert_raise ActiveRecord::PendingMigrationError do
            @pending.call(nil)
          end
        end
      end

      def test_checks_if_supported
        @connection.expect :supports_migrations?, true
        @app.expect :call, nil, [:foo]

        ActiveRecord::Migrator.stub :needs_migration?, false do
          @pending.call(:foo)
        end
      end

      def test_doesnt_check_if_unsupported
        @connection.expect :supports_migrations?, false
        @app.expect :call, nil, [:foo]

        ActiveRecord::Migrator.stub :needs_migration?, true do
          @pending.call(:foo)
        end
      end
    end
  end
end
