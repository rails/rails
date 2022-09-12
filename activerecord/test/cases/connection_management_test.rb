# frozen_string_literal: true

require "cases/helper"
require "rack"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionManagementTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      class App
        attr_reader :calls
        def initialize
          @calls = []
        end

        def call(env)
          @calls << env
          [200, {}, ["hi mom"]]
        end
      end

      def setup
        @env = {}
        @app = App.new
        @management = middleware(@app)

        # make sure we have an active connection
        assert ActiveRecord::Base.connection
        assert ActiveRecord::Base.connection_handler.active_connections?(:all)
      end

      def test_app_delegation
        manager = middleware(@app)

        manager.call @env
        assert_equal [@env], @app.calls
      end

      def test_body_responds_to_each
        _, _, body = @management.call(@env)
        bits = []
        body.each { |bit| bits << bit }
        assert_equal ["hi mom"], bits
      end

      def test_connections_are_cleared_after_body_close
        _, _, body = @management.call(@env)
        body.close
        assert_not ActiveRecord::Base.connection_handler.active_connections?(:all)
      end

      def test_active_connections_are_not_cleared_on_body_close_during_transaction
        ActiveRecord::Base.transaction do
          _, _, body = @management.call(@env)
          body.close
          assert ActiveRecord::Base.connection_handler.active_connections?(:all)
        end
      end

      def test_connections_closed_if_exception
        app       = Class.new(App) { def call(env); raise NotImplementedError; end }.new
        explosive = middleware(app)
        assert_raises(NotImplementedError) { explosive.call(@env) }
        assert_not ActiveRecord::Base.connection_handler.active_connections?(:all)
      end

      def test_connections_not_closed_if_exception_inside_transaction
        ActiveRecord::Base.transaction do
          app               = Class.new(App) { def call(env); raise RuntimeError; end }.new
          explosive         = middleware(app)
          assert_raises(RuntimeError) { explosive.call(@env) }
          assert ActiveRecord::Base.connection_handler.active_connections?(:all)
        end
      end

      test "cancel asynchronous queries if an exception is raised" do
        unless ActiveRecord::Base.connection.supports_concurrent_connections?
          skip "This adapter doesn't support asynchronous queries"
        end

        app = Class.new(App) do
          attr_reader :future_result

          def call(env)
            @future_result = ActiveRecord::Base.connection.select_all("SELECT * FROM does_not_exists", async: true)
            raise NotImplementedError
          end
        end.new

        explosive = middleware(app)
        assert_raises(NotImplementedError) { explosive.call(@env) }

        assert_raises FutureResult::Canceled do
          app.future_result.to_a
        end
      end

      test "doesn't clear active connections when running in a test case" do
        executor.wrap do
          @management.call(@env)
          assert ActiveRecord::Base.connection_handler.active_connections?(:all)
        end
      end

      test "proxy is polite to its body and responds to it" do
        body = Class.new(String) { def to_path; "/path"; end }.new
        app = lambda { |_| [200, {}, body] }
        response_body = middleware(app).call(@env)[2]
        assert_respond_to response_body, :to_path
        assert_equal "/path", response_body.to_path
      end

      test "doesn't mutate the original response" do
        original_response = [200, {}, "hi"]
        app = lambda { |_| original_response }
        middleware(app).call(@env)[2]
        assert_equal "hi", original_response.last
      end

      private
        def executor
          @executor ||= Class.new(ActiveSupport::Executor).tap do |exe|
            ActiveRecord::QueryCache.install_executor_hooks(exe)
            ActiveRecord::AsynchronousQueriesTracker.install_executor_hooks(exe)
          end
        end

        def middleware(app)
          lambda do |env|
            a, b, c = executor.wrap { app.call(env) }
            [a, b, Rack::BodyProxy.new(c) { }]
          end
        end
    end
  end
end
