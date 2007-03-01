require "#{File.dirname(__FILE__)}/abstract_unit"
$:.unshift File.dirname(__FILE__) + "/../../actionmailer/lib"

require 'stringio'
require 'cgi'

require 'dispatcher'
require 'action_controller'
require 'action_mailer'

ACTION_MAILER_DEF = <<AM
  class DispatcherTestMailer < ActionMailer::Base
  end
AM

ACTION_CONTROLLER_DEF = <<AM
  class DispatcherControllerTest < ActionController::Base
  end
AM

class DispatcherTest < Test::Unit::TestCase
  def setup
    @output = StringIO.new
    ENV['REQUEST_METHOD'] = "GET"

    Dispatcher.send(:preparation_callbacks).clear
    Dispatcher.send(:preparation_callbacks_run=, false)

    Object.const_set :ApplicationController, nil
  end

  def teardown
    Object.send :remove_const, :ApplicationController
    ENV['REQUEST_METHOD'] = nil
  end

  def test_ac_subclasses_cleared_on_reset
    Object.class_eval(ACTION_CONTROLLER_DEF)
    assert_subclasses 1, ActionController::Base
    dispatch

    GC.start # force the subclass to be collected
    assert_subclasses 0, ActionController::Base
  end

  def test_am_subclasses_cleared_on_reset
    Object.class_eval(ACTION_MAILER_DEF)
    assert_subclasses 1, ActionMailer::Base
    dispatch

    GC.start # force the subclass to be collected
    assert_subclasses 0, ActionMailer::Base
  end


  INVALID_MULTIPART = [
    'POST /foo HTTP/1.0',
    'Host: example.com',
    'Content-Type: multipart/form-data;boundary=foo'
  ]

  EMPTY_CONTENT = (INVALID_MULTIPART + [
    'Content-Length: 100',
    nil, nil
  ]).join("\r\n")

  CONTENT_LENGTH_MISMATCH = (INVALID_MULTIPART + [
    'Content-Length: 100',
    nil, nil,
    'foobar'
  ]).join("\r\n")

  NONINTEGER_CONTENT_LENGTH = (INVALID_MULTIPART + [
    'Content-Length: abc',
    nil, nil
  ]).join("\r\n")

  def test_bad_multipart_request
    old_stdin = $stdin
    [EMPTY_CONTENT, CONTENT_LENGTH_MISMATCH, NONINTEGER_CONTENT_LENGTH].each do |bad_request|
      $stdin = StringIO.new(bad_request)
      output = StringIO.new
      assert_nothing_raised { dispatch output }
      assert_equal "Status: 400 Bad Request\r\n", output.string
    end
  ensure
    $stdin = old_stdin
  end
  
  def test_preparation_callbacks
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
    a = b = nil
    Dispatcher.to_prepare(:unique_id) { a = b = 1 }
    Dispatcher.to_prepare(:unique_id) { a = 2 }
    
    Dispatcher.send :prepare_application
    assert_equal 2, a
    assert_equal nil, b
  end

  private
    def dispatch(output = @output)
      Dispatcher.dispatch(nil, {}, output)
    end

    def assert_subclasses(howmany, klass, message = klass.subclasses.inspect)
      assert_equal howmany, klass.subclasses.size, message
    end
end
