require 'abstract_unit'

uses_mocha 'dispatcher tests' do

require 'action_controller/dispatcher'

class DispatcherTest < Test::Unit::TestCase
  Dispatcher = ActionController::Dispatcher

  def setup
    @output = StringIO.new
    ENV['REQUEST_METHOD'] = 'GET'

    # Clear callbacks as they are redefined by Dispatcher#define_dispatcher_callbacks
    Dispatcher.instance_variable_set("@prepare_dispatch_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
    Dispatcher.instance_variable_set("@before_dispatch_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
    Dispatcher.instance_variable_set("@after_dispatch_callbacks", ActiveSupport::Callbacks::CallbackChain.new)

    Dispatcher.stubs(:require_dependency)

    @dispatcher = Dispatcher.new(@output)
  end

  def teardown
    ENV.delete 'REQUEST_METHOD'
  end

  def test_clears_dependencies_after_dispatch_if_in_loading_mode
    ActionController::Routing::Routes.expects(:reload).once
    ActiveSupport::Dependencies.expects(:clear).once

    dispatch(@output, false)
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
    CGI.expects(:new).raises('some multipart parsing failure')
    Dispatcher.expects(:log_failsafe_exception)

    assert_nothing_raised { dispatch }

    assert_equal "Status: 400 Bad Request\r\nContent-Type: text/html\r\n\r\n<html><body><h1>400 Bad Request</h1></body></html>", @output.string
  end

  def test_prepare_callbacks
    a = b = c = nil
    Dispatcher.to_prepare { |*args| a = b = c = 1 }
    Dispatcher.to_prepare { |*args| b = c = 2 }
    Dispatcher.to_prepare { |*args| c = 3 }

    # Ensure to_prepare callbacks are not run when defined
    assert_nil a || b || c

    # Run callbacks
    @dispatcher.send :run_callbacks, :prepare_dispatch

    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c

    # Make sure they are only run once
    a = b = c = nil
    @dispatcher.send :dispatch
    assert_nil a || b || c
  end

  def test_to_prepare_with_identifier_replaces
    a = b = nil
    Dispatcher.to_prepare(:unique_id) { |*args| a = b = 1 }
    Dispatcher.to_prepare(:unique_id) { |*args| a = 2 }

    @dispatcher.send :run_callbacks, :prepare_dispatch
    assert_equal 2, a
    assert_equal nil, b
  end

  private
    def dispatch(output = @output, cache_classes = true)
      controller = mock
      controller.stubs(:process).returns(controller)
      controller.stubs(:out).with(output).returns('response')

      ActionController::Routing::Routes.stubs(:recognize).returns(controller)

      Dispatcher.define_dispatcher_callbacks(cache_classes)
      Dispatcher.dispatch(nil, {}, output)
    end

    def assert_subclasses(howmany, klass, message = klass.subclasses.inspect)
      assert_equal howmany, klass.subclasses.size, message
    end
end

end
