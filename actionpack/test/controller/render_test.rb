require File.dirname(__FILE__) + '/../abstract_unit'

Customer = Struct.new("Customer", :name)

class RenderTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    layout :determine_layout

    def hello_world
    end

    def render_hello_world
      render "test/hello_world"
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
    
    def render_xml_hello
      @name = "David"
      render "test/hello"
    end

    def greeting
      # let's just rely on the template
    end

    def layout_test
      render_action "hello_world"
    end
    
    def builder_layout_test
      render_action "hello"
    end

    def partials_list
      @customers = [ Customer.new("david"), Customer.new("mary") ]
      render_action "list"
    end

    def modgreet
    end

    def rescue_action(e) raise end
      
    private
      def determine_layout
        case action_name 
          when "layout_test":         "layouts/standard"
          when "builder_layout_test": "layouts/builder"
        end
      end
  end

  TestController.template_root = File.dirname(__FILE__) + "/../fixtures/"
  
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
    assert_equal "test/hello_world", response.template.first_render
  end

  def test_do_with_render
    @request.action = "render_hello_world"
    assert_equal "test/hello_world", process_request.template.first_render
  end

  def test_do_with_render_from_variable
    @request.action = "render_hello_world_from_variable"
    assert_equal "hello david", process_request.body
  end

  def test_do_with_render_action
    @request.action = "render_action_hello_world"
    assert_equal "test/hello_world", process_request.template.first_render
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

  def test_private_methods
    @request.action = "determine_layout"
    assert_raises(ActionController::UnknownAction, "No action responded to [determine_layout]") { process_request }
  end

  def test_access_to_request_in_view
    ActionController::Base.view_controller_internals = false

    @request.action = "hello_world"
    response = process_request
    assert_nil response.template.assigns["request"]

    ActionController::Base.view_controller_internals = true

    @request.action = "hello_world"
    response = process_request
    assert_kind_of ActionController::AbstractRequest, response.template.assigns["request"]
  end
  
  def test_render_xml
    @request.action = "render_xml_hello"
    assert_equal "<html>\n  <p>Hello David</p>\n<p>This is grand!</p>\n</html>\n", process_request.body
  end

  def test_render_xml_with_default
    @request.action = "greeting"
    assert_equal "<p>This is grand!</p>\n", process_request.body
  end

  def test_layout_rendering
    @request.action = "layout_test"
    assert_equal "<html>Hello world!</html>", process_request.body
  end

  def test_render_xml_with_layouts
    @request.action = "builder_layout_test"
    assert_equal "<wrapper>\n<html>\n  <p>Hello </p>\n<p>This is grand!</p>\n</html>\n</wrapper>\n", process_request.body
  end

  def test_partials_list
    @request.action = "partials_list"
    assert_equal "Hello: davidHello: mary", process_request.body
  end

  def test_module_rendering
    @request.action = "modgreet"
    @request.parameters["module"] = "scope"
    assert_equal "<p>Beautiful modules!</p>", process_request.body
  end

  private
    def process_request
      TestController.process(@request, @response)
    end
end