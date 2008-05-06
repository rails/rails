require File.dirname(__FILE__) + '/../abstract_unit'

class DeprecateIvars < ActionController::Base
  def use_logger
    render :inline => "<%= logger.class -%>"
  end
  
  def use_old_logger
    render :inline => "<%= @logger.class -%>"
  end
  
  def use_action_name
    render :inline => "<%= action_name -%>"
  end
  
  def use_old_action_name
    render :inline => "<%= @action_name -%>"
  end
end

class DeprecateIvarsTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    @controller = DeprecateIvars.new
    @controller.logger = Logger.new(nil)
    
    @request.host = "rubyonrails.com"
  end
  
  def test_logger
    assert_not_deprecated { get :use_logger }
    assert_equal "Logger", @response.body
  end
  
  def test_deprecated_logger
    assert_deprecated { get :use_old_logger }
    assert_equal "Logger", @response.body
  end
  
  def test_action_name
    assert_not_deprecated { get :use_action_name }
    assert_equal "use_action_name", @response.body
  end
  
  def test_deprecated_action_name
    assert_deprecated { get :use_old_action_name }
    assert_equal "use_old_action_name", @response.body
  end
end
