require File.dirname(__FILE__) + '/../abstract_unit'

class CallerController < ActionController::Base
  def calling_from_controller
    render_component(:controller => "callee", :action => "being_called")
  end

  def calling_from_controller_with_params
    render_component(:controller => "callee", :action => "being_called", :params => { "name" => "David" })
  end

  def calling_from_controller_with_different_status_code
    render_component(:controller => "callee", :action => "blowing_up")
  end

  def calling_from_template
    render_template "Ring, ring: <%= render_component(:controller => 'callee', :action => 'being_called') %>"
  end

  def internal_caller
    render_template "Are you there? <%= render_component(:action => 'internal_callee') %>"
  end
  
  def internal_callee
    render_text "Yes, ma'am"
  end

  def rescue_action(e) raise end
end

class CalleeController < ActionController::Base
  def being_called
    render_text "#{@params["name"] || "Lady"} of the House, speaking"
  end
  
  def blowing_up
    render_text "It's game over, man, just game over, man!", "500 Internal Server Error"
  end

  def rescue_action(e) raise end
end

class ComponentsTest < Test::Unit::TestCase
  def setup
    @controller = CallerController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_calling_from_controller
    get :calling_from_controller
    assert_equal "Lady of the House, speaking", @response.body
  end

  def test_calling_from_controller_with_params
    get :calling_from_controller_with_params
    assert_equal "David of the House, speaking", @response.body
  end
  
  def test_calling_from_controller_with_different_status_code
    get :calling_from_controller_with_different_status_code
    assert_equal 500, @response.response_code
  end

  def test_calling_from_template
    get :calling_from_template
    assert_equal "Ring, ring: Lady of the House, speaking", @response.body
  end
  
  def test_internal_calling
    get :internal_caller
    assert_equal "Are you there? Yes, ma'am", @response.body
  end
end