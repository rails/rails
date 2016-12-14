require "cases/helper"

module ActiveRecord
  class Migration
    class PendingMigrationsTest < ActiveRecord::TestCase
      def setup
        super
        @connection = Minitest::Mock.new
        @app = Minitest::Mock.new
        conn = @connection
        @pending = Class.new(CheckPending) {
          define_method(:connection) { conn }
        }.new(@app)
        @pending.instance_variable_set :@last_check, -1 # Force checking
      end

      def teardown
        assert @connection.verify
        assert @app.verify
        super
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
