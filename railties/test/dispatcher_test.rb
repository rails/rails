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
    setup_minimal_environment
  end

  def teardown
    ENV['REQUEST_METHOD'] = nil
    teardown_minimal_environment
  end

  def test_ac_subclasses_cleared_on_reset
    Object.class_eval(ACTION_CONTROLLER_DEF)
    assert_equal 1, ActionController::Base.subclasses.length
    Dispatcher.dispatch(CGI.new, ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS, @output)

    GC.start # force the subclass to be collected
    assert_equal 0, ActionController::Base.subclasses.length
  end

  def test_am_subclasses_cleared_on_reset
    Object.class_eval(ACTION_MAILER_DEF)
    assert_equal 1, ActionMailer::Base.subclasses.length
    Dispatcher.dispatch(CGI.new, ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS, @output)

    GC.start # force the subclass to be collected
    assert_equal 0, ActionMailer::Base.subclasses.length
  end

  private

    def setup_minimal_environment
      value = Dependencies::LoadingModule.root
      Object.const_set("Controllers", value)
    end

    def teardown_minimal_environment
      Object.send(:remove_const, "Controllers")
    end
end
