# frozen_string_literal: true

require "abstract_unit"
require "timeout"

module ActionController
  class LiveThreadingFixTest < ActionController::TestCase
    class ThreadingTestController < ActionController::Base
      include ActionController::Live

      attr_accessor :execution_thread_id, :thread_local_value, :db_state, :query_count

      def streaming_action
        response.headers["Content-Type"] = "text/event-stream"
        
        # Capture the thread ID where this action executes
        @execution_thread_id = Thread.current.object_id
        
        # Capture thread local value
        @thread_local_value = Thread.current[:test_setting]
        
        # Simulate streaming
        response.stream.write "data: streaming\n"
        response.stream.write "data: complete\n"
        response.stream.close
      end

      def long_running_stream
        response.headers["Content-Type"] = "text/event-stream"
        
        # Simulate long-running operation
        sleep 0.1
        
        response.stream.write "data: long operation complete\n"
        response.stream.close
      end

      def database_simulation
        response.headers["Content-Type"] = "text/event-stream"
        
        # Simulate database connection state
        Thread.current[:db_connection] = "connected"
        Thread.current[:query_count] = 0
        
        # Simulate some work
        response.stream.write "data: processing\n"
        
        # Verify state is preserved
        @db_state = Thread.current[:db_connection]
        @query_count = Thread.current[:query_count]
        
        response.stream.write "data: complete\n"
        response.stream.close
      end

      # Make private methods accessible for testing
      def test_new_controller_thread(&block)
        new_controller_thread(&block)
      end

      def test_clean_up_thread_locals(locals, thread)
        clean_up_thread_locals(locals, thread)
      end
    end

    tests ThreadingTestController

    def setup
      super
      @controller.execution_thread_id = nil
      @controller.thread_local_value = nil
      @controller.db_state = nil
      @controller.query_count = nil
    end

    def test_action_executes_in_test_environment
      # In test environment, threading is disabled, so actions run in main thread
      original_thread_id = Thread.current.object_id
      
      get :streaming_action
      
      # In test environment, action should execute in same thread
      assert_equal original_thread_id, @controller.execution_thread_id
      assert_not_nil @controller.execution_thread_id
      
      # Verify streaming worked
      assert_match(/data: streaming/, response.body)
      assert_match(/data: complete/, response.body)
    end

    def test_streaming_basic_functionality
      # Test basic streaming functionality works
      get :streaming_action
      
      # Verify streaming works
      assert_match(/data: streaming/, response.body)
      assert_match(/data: complete/, response.body)
    end

    def test_streaming_functionality_works
      # Test that streaming works correctly in test environment
      get :long_running_stream
      
      # Verify streaming completed
      assert_match(/data: long operation complete/, response.body)
    end

    def test_database_simulation_functionality
      # Test database simulation functionality works
      get :database_simulation
      
      # Verify streaming works
      assert_match(/data: processing/, response.body)
      assert_match(/data: complete/, response.body)
    end

    def test_no_execution_state_sharing
      # Verify that IsolatedExecutionState methods are not called
      # This prevents the connection corruption issues
      
      # Mock the IsolatedExecutionState to track calls
      original_share_with = ActiveSupport::IsolatedExecutionState.method(:share_with)
      original_clear = ActiveSupport::IsolatedExecutionState.method(:clear)
      
      share_called = false
      clear_called = false
      
      ActiveSupport::IsolatedExecutionState.define_singleton_method(:share_with) do |*args|
        share_called = true
        original_share_with.call(*args)
      end
      
      ActiveSupport::IsolatedExecutionState.define_singleton_method(:clear) do |*args|
        clear_called = true
        original_clear.call(*args)
      end
      
      begin
        get :streaming_action
        
        # Verify these methods were NOT called (preventing corruption)
        assert_not share_called, "IsolatedExecutionState.share_with should not be called"
        assert_not clear_called, "IsolatedExecutionState.clear should not be called"
        
      ensure
        # Restore original methods
        ActiveSupport::IsolatedExecutionState.define_singleton_method(:share_with, original_share_with)
        ActiveSupport::IsolatedExecutionState.define_singleton_method(:clear, original_clear)
      end
    end

    def test_cleanup_thread_locals_works
      # Verify the clean_up_thread_locals method exists and works
      assert_respond_to @controller, :test_clean_up_thread_locals
      
      # Test with some thread locals
      test_thread = Thread.new { Thread.current[:test_key] = "test_value" }
      test_thread.join
      
      # Verify cleanup method can be called
      assert_nothing_raised do
        @controller.test_clean_up_thread_locals([:test_key], test_thread)
      end
      
      # Clean up test thread
      test_thread.kill
      test_thread.join
    end

    def test_new_controller_thread_method_exists
      # Verify new_controller_thread method exists
      assert_respond_to @controller, :test_new_controller_thread
      
      # In test environment, this should just yield (threading disabled)
      execution_thread_id = nil
      
      @controller.test_new_controller_thread do
        execution_thread_id = Thread.current.object_id
      end
      
      # In test environment, should execute in same thread
      assert_equal Thread.current.object_id, execution_thread_id
      assert_not_nil execution_thread_id
    end

    def test_basic_threading_works
      # Simple test to verify threading works in test environment
      original_thread_id = Thread.current.object_id
      new_thread_id = nil
      
      thread = Thread.new do
        new_thread_id = Thread.current.object_id
      end
      
      thread.join
      
      # Verify we got a different thread ID
      assert_not_equal original_thread_id, new_thread_id
      assert_not_nil new_thread_id
    end

    def test_live_module_methods_exist
      # Test that our ActionController::Live methods exist and are accessible
      live_module = ActionController::Live
      
      # Create a mock controller that includes ActionController::Live
      controller_class = Class.new do
        include ActionController::Live
      end
      
      controller = controller_class.new
      
      # Verify the methods exist (new_controller_thread is private)
      assert_respond_to controller, :new_controller_thread
      
      # clean_up_thread_locals is private, so use send to check
      assert controller.respond_to?(:clean_up_thread_locals, true)
      
      # Verify method source (in test environment, it comes from test_case.rb override)
      method_source = controller.method(:new_controller_thread).source_location
      # In test environment, this method is overridden by test_case.rb
      # In production, it would come from action_controller/metal/live.rb
      assert_includes method_source[0], "action_controller"
    end
  end
end
