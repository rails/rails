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

  def render_action_hello_world_with_symbol
    render_action :hello_world
  end

  def render_text_hello_world
    render_text "hello world"
  end

  def render_json_hello_world
    render_json({:hello => 'world'}.to_json)
  end

  def render_json_hello_world_with_callback
    render_json({:hello => 'world'}.to_json, 'alert')
  end

  def render_symbol_json
    render :json => {:hello => 'world'}.to_json
  end

  def render_custom_code
    render_text "hello world", "404 Moved"
  end

  def render_text_appendix
    render_text "hello world"
    render_text ", goodbye!", "404 Not Found", true
  end

  def render_nothing_with_appendix
    render_text "appended", nil, true
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

  def builder_partial_test
    render_action "hello_world_container"
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
        when "render_symbol_json":  "layouts/standard"  # to make sure layouts don't interfere
      end
    end
end

TestController.template_root = File.dirname(__FILE__) + "/../fixtures/"
Fun::GamesController.template_root = File.dirname(__FILE__) + "/../fixtures/"

class RenderTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = TestController.new

    @request.host = "www.nextangle.com"
  end

  def test_simple_show
    get :hello_world
    assert_response 200
    assert_template "test/hello_world"
  end

  def test_do_with_render
    assert_deprecated_render { get :render_hello_world }
    assert_template "test/hello_world"
  end

  def test_do_with_render_from_variable
    get :render_hello_world_from_variable
    assert_equal "hello david", @response.body
  end

  def test_do_with_render_action
    get :render_action_hello_world
    assert_template "test/hello_world"
  end

  def test_do_with_render_action_with_symbol
    get :render_action_hello_world_with_symbol
    assert_template "test/hello_world"
  end

  def test_do_with_render_text
    get :render_text_hello_world
    assert_equal "hello world", @response.body
  end

  def test_do_with_render_json
    get :render_json_hello_world
    assert_equal '{hello: "world"}', @response.body
    assert_equal 'application/json', @response.content_type
  end

  def test_do_with_render_json_with_callback
    get :render_json_hello_world_with_callback
    assert_equal 'alert({hello: "world"})', @response.body
    assert_equal 'application/json', @response.content_type
  end

  def test_do_with_render_symbol_json
    get :render_symbol_json
    assert_equal '{hello: "world"}', @response.body
    assert_equal 'application/json', @response.content_type
  end

  def test_do_with_render_custom_code
    get :render_custom_code
    assert_response 404
  end

  def test_do_with_render_text_appendix
    get :render_text_appendix
    assert_response 404
    assert_equal 'hello world, goodbye!', @response.body
  end

  def test_do_with_render_nothing_with_appendix
    get :render_nothing_with_appendix
    assert_response 200
    assert_equal 'appended', @response.body
  end

  def test_attempt_to_access_object_method
    assert_raises(ActionController::UnknownAction, "No action responded to [clone]") { get :clone }
  end

  def test_private_methods
    assert_raises(ActionController::UnknownAction, "No action responded to [determine_layout]") { get :determine_layout }
  end

  def test_render_xml
    assert_deprecated_render { get :render_xml_hello }
    assert_equal "<html>\n  <p>Hello David</p>\n<p>This is grand!</p>\n</html>\n", @response.body
  end

  def test_render_xml_with_default
    get :greeting
    assert_equal "<p>This is grand!</p>\n", @response.body
  end

  def test_render_xml_with_partial
    get :builder_partial_test
    assert_equal "<test>\n  <hello/>\n</test>\n", @response.body
  end

  def test_layout_rendering
    get :layout_test
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_render_xml_with_layouts
    get :builder_layout_test
    assert_equal "<wrapper>\n<html>\n  <p>Hello </p>\n<p>This is grand!</p>\n</html>\n</wrapper>\n", @response.body
  end

  # def test_partials_list
  #   get :partials_list
  #   assert_equal "goodbyeHello: davidHello: marygoodbye\n", process_request.body
  # end

  def test_partial_only
    get :partial_only
    assert_equal "only partial", @response.body
  end

  def test_render_to_string
    get :hello_in_a_string
    assert_equal "How's there? goodbyeHello: davidHello: marygoodbye\n", @response.body
  end

  def test_render_to_string_resets_assigns
    get :render_to_string_test
    assert_equal "The value of foo is: ::this is a test::\n", @response.body
  end

  def test_nested_rendering
    @controller = Fun::GamesController.new
    get :hello_world
    assert_equal "Living in a nested world", @response.body
  end

  def test_accessing_params_in_template
    get :accessing_params_in_template, :name => "David"
    assert_equal "Hello: David", @response.body
  end

  def test_accessing_local_assigns_in_inline_template
    get :accessing_local_assigns_in_inline_template, :local_name => "Local David"
    assert_equal "Goodbye, Local David", @response.body
  end

  def test_accessing_local_assigns_in_inline_template_with_string_keys
    get :accessing_local_assigns_in_inline_template_with_string_keys, :local_name => "Local David"
    assert_equal "Goodbye, Local David", @response.body
  end

  protected
    def assert_deprecated_render(&block)
      assert_deprecated(/render/, &block)
    end
end
