require File.dirname(__FILE__) + '/../abstract_unit'

class RenderTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    def hello_world
    end

    def render_hello_world
      render "hello_world"
    end

    def render_hello_world_from_variable
      @person = "david"
      render_text "hello #{@person}"
    end

    def render_action_hello_world
      render_action "hello_world"
    end
    
    def render_text_hello_world
      render_text "hello world"
    end

    def render_custom_code
      render_text "hello world", "404 Moved"
    end

    def rescue_action(e) raise end
  end
  
  class TestLayoutController < ActionController::Base
    layout "layouts/standard"
    
    def hello_world
    end
    
    def hello_world_outside_layout
    end

    def rescue_action(e)
      raise unless ActionController::MissingTemplate === e
    end
  end

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end

  def test_simple_show
    @request.action = "hello_world"
    response = process_request
    assert_equal "200 OK", response.headers["Status"]
    assert_equal "test/hello_world", response.template.template_name
  end

  def test_do_with_render
    @request.action = "render_hello_world"
    assert_equal "hello_world", process_request.template.template_name
  end

  def test_do_with_render_from_variable
    @request.action = "render_hello_world_from_variable"
    assert_equal "hello david", process_request.body
  end

  def test_do_with_render_action
    @request.action = "render_action_hello_world"
    assert_equal "test/hello_world", process_request.template.template_name
  end

  def test_do_with_render_text
    @request.action = "render_text_hello_world"
    assert_equal "hello world", process_request.body
  end

  def test_do_with_render_custom_code
    @request.action = "render_custom_code"
    assert_equal "404 Moved", process_request.headers["Status"]
  end

  def test_attempt_to_access_object_method
    @request.action = "clone"
    assert_raises(ActionController::UnknownAction, "No action responded to [clone]") { process_request }
  end

  def test_access_to_request_in_view
    ActionController::Base.view_controller_internals = false

    @request.action = "hello_world"
    response = process_request
    assert_nil response.template.assigns["request"]

    ActionController::Base.view_controller_internals = true

    @request.action = "hello_world"
    response = process_request
    assert_kind_of ActionController::Request, response.template.assigns["request"]
  end
  
  def test_layout_rendering
  end

  private
    def process_request
      TestController.process(@request, @response)
    end
end