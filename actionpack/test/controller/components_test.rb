require File.dirname(__FILE__) + '/../abstract_unit'

class CallerController < ActionController::Base
  def calling_from_controller
    render_component(:controller => "callee", :action => "being_called")
  end

  def calling_from_controller_with_params
    render_component(:controller => "callee", :action => "being_called", :params => { "name" => "David" })
  end

  def calling_from_template
    render_template "Ring, ring: <%= render_component(:controller => 'callee', :action => 'being_called') %>"
  end

  def rescue_action(e) raise end
end

class CalleeController < ActionController::Base
  def being_called
    render_text "#{@params["name"] || "Lady"} of the House, speaking"
  end

  def rescue_action(e) raise end
end

class RenderTest < Test::Unit::TestCase
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

  def test_calling_from_template
    get :calling_from_template
    assert_equal "Ring, ring: Lady of the House, speaking", @response.body
  end
end