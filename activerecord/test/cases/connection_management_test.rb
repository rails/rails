require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionManagementTest < ActiveRecord::TestCase
      class App
        attr_reader :calls
        def initialize
          @calls = []
        end

        def call(env)
          @calls << env
          [200, {}, [['hi mom']]]
        end
      end

      def setup
        @env = {}
        @app = App.new
        @management = ConnectionManagement.new(@app)

        @connections_cleared = false
        ActiveRecord::Base.stubs(:clear_active_connections!).with { @connections_cleared = true }
      end

      def test_app_delegation
        manager = ConnectionManagement.new(@app)

        manager.call @env
        assert_equal [@env], @app.calls
      end

      test "clears active connections after each call" do
        @management.call(@env)
        assert @connections_cleared
      end

      test "doesn't clear active connections when running in a test case" do
        @env['rack.test'] = true
        @management.call(@env)
        assert !@connections_cleared
      end
    end
  end
end
