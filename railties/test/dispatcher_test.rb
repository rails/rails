require "#{File.dirname(__FILE__)}/abstract_unit"

uses_mocha 'dispatcher tests' do

$:.unshift File.dirname(__FILE__) + "/../../actionmailer/lib"

require 'stringio'
require 'cgi'

require 'dispatcher'
require 'action_controller'
require 'action_mailer'


class DispatcherTest < Test::Unit::TestCase
  def setup
    @output = StringIO.new
    ENV['REQUEST_METHOD'] = "GET"

    Dispatcher.send(:preparation_callbacks).clear
    Dispatcher.send(:preparation_callbacks_run=, false)

    Object.const_set 'ApplicationController', nil
  end

  def teardown
    ENV['REQUEST_METHOD'] = nil
    Object.send :remove_const, 'ApplicationController'
  end

  def test_clears_dependencies_after_dispatch_if_in_loading_mode
    Dependencies.stubs(:load?).returns(true)

    ActionController::Routing::Routes.expects(:reload).once
    Dependencies.expects(:clear).once

    dispatch
  end

  def test_clears_dependencies_after_dispatch_if_not_in_loading_mode
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

  def test_preparation_callbacks
    ActionController::Routing::Routes.stubs(:reload)

    old_mechanism = Dependencies.mechanism
    
    a = b = c = nil
    Dispatcher.to_prepare { a = b = c = 1 }
    Dispatcher.to_prepare { b = c = 2 }
    Dispatcher.to_prepare { c = 3 }
    
    Dispatcher.send :prepare_application
    
    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c
    
    # When mechanism is :load, perform the callbacks each request:
    Dependencies.mechanism = :load
    a = b = c = nil
    Dispatcher.send :prepare_application
    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c
    
    # But when not :load, make sure they are only run once
    a = b = c = nil
    Dependencies.mechanism = :not_load
    Dispatcher.send :prepare_application
    assert_equal nil, a || b || c
  ensure
    Dependencies.mechanism = old_mechanism
  end
  
  def test_to_prepare_with_identifier_replaces
    ActionController::Routing::Routes.stubs(:reload)

    a = b = nil
    Dispatcher.to_prepare(:unique_id) { a = b = 1 }
    Dispatcher.to_prepare(:unique_id) { a = 2 }
    
    Dispatcher.send :prepare_application
    assert_equal 2, a
    assert_equal nil, b
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

end # uses_mocha
