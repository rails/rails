require File.dirname(__FILE__) + '/../abstract_unit'

unless defined?(Customer)
  Customer = Struct.new("Customer", :name)
end

module Fun
  class GamesController < ActionController::Base
    def hello_world
    end
  end
end


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
    @test_unchanged = 'hello'
    @customers = [ Customer.new("david"), Customer.new("mary") ]
    render_action "list"
  end

  def partial_only
    render_partial
  end

  def hello_in_a_string
    @customers = [ Customer.new("david"), Customer.new("mary") ]
    render_text "How's there? #{render_to_string("test/list")}"
  end
  
  def accessing_params_in_template
    render_template "Hello: <%= params[:name] %>"
  end

  def accessing_local_assigns_in_inline_template
    name = params[:local_name]
    render :inline => "<%= 'Goodbye, ' + local_name %>",
           :locals => { :local_name => name }
  end
  
  def accessing_local_assigns_in_inline_template_with_string_keys
    name = params[:local_name]
    ActionView::Base.local_assigns_support_string_keys = true
    render :inline => "<%= 'Goodbye, ' + local_name %>",
           :locals => { "local_name" => name }
    ActionView::Base.local_assigns_support_string_keys = false
  end

  def render_to_string_test
    @foo = render_to_string :inline => "this is a test"
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
Fun::GamesController.template_root = File.dirname(__FILE__) + "/../fixtures/"

class RenderTest < Test::Unit::TestCase
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
    view_internals_old_value = ActionController::Base.view_controller_internals

    ActionController::Base.view_controller_internals = false
    ActionController::Base.protected_variables_cache = nil

    @request.action = "hello_world"
    response = process_request
    assert_nil response.template.assigns["request"]

    ActionController::Base.view_controller_internals = true
    ActionController::Base.protected_variables_cache = nil

    @request.action = "hello_world"
    response = process_request
    assert_kind_of ActionController::AbstractRequest,  response.template.assigns["request"]

    ActionController::Base.view_controller_internals = view_internals_old_value
    ActionController::Base.protected_variables_cache = nil
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

  # def test_partials_list
  #   @request.action = "partials_list"
  #   assert_equal "goodbyeHello: davidHello: marygoodbye\n", process_request.body
  # end

  def test_partial_only
    @request.action = "partial_only"
    assert_equal "only partial", process_request.body
  end

  def test_render_to_string
    @request.action = "hello_in_a_string"
    assert_equal "How's there? goodbyeHello: davidHello: marygoodbye\n", process_request.body
  end

  def test_render_to_string_resets_assigns
    @request.action = "render_to_string_test"
    assert_equal "The value of foo is: ::this is a test::\n", process_request.body
  end

  def test_nested_rendering
    @request.action = "hello_world"
    assert_equal "Living in a nested world", Fun::GamesController.process(@request, @response).body
  end

  def test_accessing_params_in_template
    @request.action = "accessing_params_in_template"
    @request.query_parameters[:name] = "David"
    assert_equal "Hello: David", process_request.body
  end

  def test_accessing_local_assigns_in_inline_template
    @request.action = "accessing_local_assigns_in_inline_template"
    @request.query_parameters[:local_name] = "Local David"
    assert_equal "Goodbye, Local David", process_request.body
  end
  
  def test_accessing_local_assigns_in_inline_template_with_string_keys
    @request.action = "accessing_local_assigns_in_inline_template_with_string_keys"
    @request.query_parameters[:local_name] = "Local David"
    assert_equal "Goodbye, Local David", process_request.body
  end

  private
    def process_request
      TestController.process(@request, @response)
    end
end
