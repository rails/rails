require File.dirname(__FILE__) + '/../abstract_unit'

silence_warnings { Customer = Struct.new("Customer", :name) }

module Fun
  class GamesController < ActionController::Base
    def hello_world
    end
  end
end

class NewRenderTestController < ActionController::Base
  layout :determine_layout

  def self.controller_name; "test"; end
  def self.controller_path; "test"; end

  def hello_world
  end

  def render_hello_world
    render :template => "test/hello_world"
  end

  def render_hello_world_from_variable
    @person = "david"
    render :text => "hello #{@person}"
  end

  def render_action_hello_world
    render :action => "hello_world"
  end
  
  def render_text_hello_world
    render :text => "hello world"
  end

  def render_custom_code
    render :text => "hello world", :status => "404 Moved"
  end
  
  def render_xml_hello
    @name = "David"
    render :template => "test/hello"
  end

  def greeting
    # let's just rely on the template
  end

  def layout_test
    render :action => "hello_world"
  end

  def layout_test_with_different_layout
    render :action => "hello_world", :layout => "standard"
  end
  
  def rendering_without_layout
    render :action => "hello_world", :layout => false
  end
  
  def rendering_nothing_on_layout
    render :nothing => true
  end
  
  def builder_layout_test
    render :action => "hello"
  end

  def partials_list
    @test_unchanged = 'hello'
    @customers = [ Customer.new("david"), Customer.new("mary") ]
    render :action => "list"
  end

  def partial_only
    render :partial => true
  end

  def partial_only_with_layout
    render :partial => "partial_only", :layout => true
  end

  def hello_in_a_string
    @customers = [ Customer.new("david"), Customer.new("mary") ]
    render :text =>  "How's there? #{render_to_string("test/list")}"
  end
  
  def accessing_params_in_template
    render :inline =>  "Hello: <%= params[:name] %>"
  end

  def accessing_params_in_template_with_layout
    render :inline =>  "Hello: <%= params[:name] %>", :layout => nil
  end

  def render_with_explicit_template
    render "test/hello_world"
  end

  def double_render
    render :text => "hello"
    render :text => "world"
  end

  def double_redirect
    redirect_to :action => "double_render"
    redirect_to :action => "double_render"
  end

  def render_and_redirect
    render :text => "hello"
    redirect_to :action => "double_render"
  end

  def rescue_action(e) raise end
    
  private
    def determine_layout
      case action_name 
        when "hello_world", "layout_test", "rendering_without_layout",
             "rendering_nothing_on_layout", "render_text_hello_world",
             "partial_only", "partial_only_with_layout",
             "accessing_params_in_template",
             "accessing_params_in_template_with_layout",
             "render_with_explicit_template"
          "layouts/standard"
        when "builder_layout_test"
          "layouts/builder"
      end
    end
end

NewRenderTestController.template_root = File.dirname(__FILE__) + "/../fixtures/"
Fun::GamesController.template_root = File.dirname(__FILE__) + "/../fixtures/"

class NewRenderTest < Test::Unit::TestCase
  def setup
    @controller = NewRenderTestController.new

    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = Logger.new(nil)

    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end

  def test_simple_show
    get :hello_world
    assert_response :success
    assert_template "test/hello_world"
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_do_with_render
    get :render_hello_world
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

  def test_do_with_render_text
    get :render_text_hello_world
    assert_equal "hello world", @response.body
  end

  def test_do_with_render_custom_code
    get :render_custom_code
    assert_response :missing
  end

  def test_attempt_to_access_object_method
    assert_raises(ActionController::UnknownAction, "No action responded to [clone]") { get :clone }
  end

  def test_private_methods
    assert_raises(ActionController::UnknownAction, "No action responded to [determine_layout]") { get :determine_layout }
  end

  def test_access_to_request_in_view
    ActionController::Base.view_controller_internals = false

    get :hello_world
    assert_nil(assigns["request"])

    ActionController::Base.view_controller_internals = true

    get :hello_world
    assert_kind_of ActionController::AbstractRequest, assigns["request"]
  end
  
  def test_render_xml
    get :render_xml_hello
    assert_equal "<html>\n  <p>Hello David</p>\n<p>This is grand!</p>\n</html>\n", @response.body
  end

  def test_render_xml_with_default
    get :greeting
    assert_equal "<p>This is grand!</p>\n", @response.body
  end

  def test_layout_rendering
    get :layout_test
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_layout_test_with_different_layout
    get :layout_test_with_different_layout
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_rendering_without_layout
    get :rendering_without_layout
    assert_equal "Hello world!", @response.body
  end

  def test_rendering_nothing_on_layout
    get :rendering_nothing_on_layout
    assert_equal "", @response.body
  end

  def test_render_xml_with_layouts
    get :builder_layout_test
    assert_equal "<wrapper>\n<html>\n  <p>Hello </p>\n<p>This is grand!</p>\n</html>\n</wrapper>\n", @response.body
  end

  # def test_partials_list
  #   get :partials_list
  #   assert_equal "goodbyeHello: davidHello: marygoodbye\n", @response.body
  # end

  def test_partial_only
    get :partial_only
    assert_equal "only partial", @response.body
  end

  def test_partial_only_with_layout
    get :partial_only_with_layout
    assert_equal "<html>only partial</html>", @response.body
  end

  def test_render_to_string
    get :hello_in_a_string
    assert_equal "How's there? goodbyeHello: davidHello: marygoodbye\n", @response.body
  end

  def test_nested_rendering
    get :hello_world
    assert_equal "Living in a nested world", Fun::GamesController.process(@request, @response).body
  end

  def test_accessing_params_in_template
    get :accessing_params_in_template, :name => "David"
    assert_equal "Hello: David", @response.body
  end

  def test_accessing_params_in_template_with_layout
    get :accessing_params_in_template_with_layout, :name => "David"
    assert_equal "<html>Hello: David</html>", @response.body
  end

  def test_render_with_explicit_template
    get :render_with_explicit_template
    assert_response :success
  end

  def test_double_render
    assert_raises(ActionController::DoubleRenderError) { get :double_render }
  end

  def test_double_redirect
    assert_raises(ActionController::DoubleRenderError) { get :double_redirect }
  end

  def test_render_and_redirect
    assert_raises(ActionController::DoubleRenderError) { get :render_and_redirect }
  end
end
