require 'abstract_unit'

class DispatcherTest < Test::Unit::TestCase
  Dispatcher = ActionController::Dispatcher

  def setup
    ENV['REQUEST_METHOD'] = 'GET'

    Dispatcher.middleware = ActionController::MiddlewareStack.new do |middleware|
      middlewares = File.expand_path(File.join(File.dirname(__FILE__), "../../lib/action_controller/middlewares.rb"))
      middleware.instance_eval(File.read(middlewares))
    end

    # Clear callbacks as they are redefined by Dispatcher#define_dispatcher_callbacks
    Dispatcher.instance_variable_set("@prepare_dispatch_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
    Dispatcher.instance_variable_set("@before_dispatch_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
    Dispatcher.instance_variable_set("@after_dispatch_callbacks", ActiveSupport::Callbacks::CallbackChain.new)

    Dispatcher.stubs(:require_dependency)
  end

  def teardown
    ENV.delete 'REQUEST_METHOD'
  end

  def test_clears_dependencies_after_dispatch_if_in_loading_mode
    ActiveSupport::Dependencies.expects(:clear).once
    dispatch(false)
  end

  def test_reloads_routes_before_dispatch_if_in_loading_mode
    ActionController::Routing::Routes.expects(:reload).once
    dispatch(false)
  end

  def test_leaves_dependencies_after_dispatch_if_not_in_loading_mode
    ActionController::Routing::Routes.expects(:reload).never
    ActiveSupport::Dependencies.expects(:clear).never

    dispatch
  end

  # Stub out dispatch error logger
  class << Dispatcher
    def log_failsafe_exception(status, exception); end
  end

  def test_failsafe_response
    Dispatcher.any_instance.expects(:dispatch).raises('b00m')
    ActionController::Failsafe.any_instance.expects(:log_failsafe_exception)

    assert_nothing_raised do
      assert_equal [
        500,
        {"Content-Type" => "text/html"},
        "<html><body><h1>500 Internal Server Error</h1></body></html>"
      ], dispatch
    end
  end

  def test_prepare_callbacks
    a = b = c = nil
    Dispatcher.to_prepare { |*args| a = b = c = 1 }
    Dispatcher.to_prepare { |*args| b = c = 2 }
    Dispatcher.to_prepare { |*args| c = 3 }

    # Ensure to_prepare callbacks are not run when defined
    assert_nil a || b || c

    # Run callbacks
    Dispatcher.run_prepare_callbacks

    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c

    # Make sure they are only run once
    a = b = c = nil
    dispatch
    assert_nil a || b || c
  end

  def test_to_prepare_with_identifier_replaces
    a = b = nil
    Dispatcher.to_prepare(:unique_id) { |*args| a = b = 1 }
    Dispatcher.to_prepare(:unique_id) { |*args| a = 2 }

    Dispatcher.run_prepare_callbacks
    assert_equal 2, a
    assert_equal nil, b
  end

  private
    def dispatch(cache_classes = true)
      ActionController::Routing::RouteSet.any_instance.stubs(:call).returns([200, {}, 'response'])
      Dispatcher.define_dispatcher_callbacks(cache_classes)
      Dispatcher.new.call({})
    end

    def assert_subclasses(howmany, klass, message = klass.subclasses.inspect)
      assert_equal howmany, klass.subclasses.size, message
    end
end
