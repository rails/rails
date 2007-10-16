require "#{File.dirname(__FILE__)}/../abstract_unit"

uses_mocha 'dispatcher tests' do

require 'action_controller/dispatcher'

class DispatcherTest < Test::Unit::TestCase
  Dispatcher = ActionController::Dispatcher

  def setup
    @output = StringIO.new
    ENV['REQUEST_METHOD'] = 'GET'

    Dispatcher.callbacks[:prepare].clear
    @dispatcher = Dispatcher.new(@output)
  end

  def teardown
    ENV['REQUEST_METHOD'] = nil
  end

  def test_clears_dependencies_after_dispatch_if_in_loading_mode
    Dependencies.stubs(:load?).returns(true)

    ActionController::Routing::Routes.expects(:reload).once
    Dependencies.expects(:clear).once

    dispatch
  end

  def test_leaves_dependencies_after_dispatch_if_not_in_loading_mode
    Dependencies.stubs(:load?).returns(false)

    ActionController::Routing::Routes.expects(:reload).never
    Dependencies.expects(:clear).never

    dispatch
  end

  def test_failsafe_response
    CGI.expects(:new).raises('some multipart parsing failure')

    ActionController::Routing::Routes.stubs(:reload)
    Dispatcher.stubs(:log_failsafe_exception)

    assert_nothing_raised { dispatch }

    assert_equal "Status: 400 Bad Request\r\nContent-Type: text/html\r\n\r\n<html><body><h1>400 Bad Request</h1></body></html>", @output.string
  end

  def test_reload_application_sets_unprepared_if_loading_dependencies
    Dependencies.stubs(:load?).returns(false)
    ActionController::Routing::Routes.expects(:reload).never
    @dispatcher.unprepared = false
    @dispatcher.send!(:reload_application)
    assert !@dispatcher.unprepared

    Dependencies.stubs(:load?).returns(true)
    ActionController::Routing::Routes.expects(:reload).once
    @dispatcher.send!(:reload_application)
    assert @dispatcher.unprepared
  end

  def test_prepare_application_runs_callbacks_if_unprepared
    a = b = c = nil
    Dispatcher.to_prepare { a = b = c = 1 }
    Dispatcher.to_prepare { b = c = 2 }
    Dispatcher.to_prepare { c = 3 }

    # Skip the callbacks when already prepared.
    @dispatcher.unprepared = false
    @dispatcher.send! :prepare_application
    assert_nil a || b || c

    # Perform the callbacks when unprepared.
    @dispatcher.unprepared = true
    @dispatcher.send! :prepare_application
    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c

    # But when not :load, make sure they are only run once
    a = b = c = nil
    @dispatcher.send! :prepare_application
    assert_nil a || b || c
  end

  def test_to_prepare_with_identifier_replaces
    a = b = nil
    Dispatcher.to_prepare(:unique_id) { a = b = 1 }
    Dispatcher.to_prepare(:unique_id) { a = 2 }

    @dispatcher.unprepared = true
    @dispatcher.send! :prepare_application
    assert_equal 2, a
    assert_equal nil, b
  end

  def test_to_prepare_only_runs_once_if_not_loading_dependencies
    Dependencies.stubs(:load?).returns(false)
    called = 0
    Dispatcher.to_prepare(:unprepared_test) { called += 1 }
    2.times { dispatch }
    assert_equal 1, called
  end

  private
    def dispatch(output = @output)
      controller = mock
      controller.stubs(:process).returns(controller)
      controller.stubs(:out).with(output).returns('response')

      ActionController::Routing::Routes.stubs(:recognize).returns(controller)

      Dispatcher.dispatch(nil, {}, output)
    end

    def assert_subclasses(howmany, klass, message = klass.subclasses.inspect)
      assert_equal howmany, klass.subclasses.size, message
    end
end

end
