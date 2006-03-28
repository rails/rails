$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../../actionpack/lib"
$:.unshift File.dirname(__FILE__) + "/../../actionmailer/lib"

require 'test/unit'
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
  end

  def teardown
    ENV['REQUEST_METHOD'] = nil
  end

  def test_ac_subclasses_cleared_on_reset
    Object.class_eval(ACTION_CONTROLLER_DEF)
    assert_equal 1, ActionController::Base.subclasses.length
    dispatch

    GC.start # force the subclass to be collected
    assert_equal 0, ActionController::Base.subclasses.length
  end

  def test_am_subclasses_cleared_on_reset
    Object.class_eval(ACTION_MAILER_DEF)
    assert_equal 1, ActionMailer::Base.subclasses.length
    dispatch

    GC.start # force the subclass to be collected
    assert_equal 0, ActionMailer::Base.subclasses.length
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
      assert_nothing_raised do
        Dispatcher.dispatch(nil, ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS, output)
      end
      assert_equal "Status: 400 Bad Request\r\n", output.string
    end
  ensure
    $stdin = old_stdin
  end

  private
    def dispatch
      Dispatcher.dispatch(nil, ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS, @output)
    end
end
