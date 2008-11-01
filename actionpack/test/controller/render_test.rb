require 'abstract_unit'
require 'controller/fake_models'

module Fun
  class GamesController < ActionController::Base
    def hello_world
    end
  end
end

class MockLogger
  attr_reader :logged

  def initialize
    @logged = []
  end

  def method_missing(method, *args)
    @logged << args.first
  end
end

class TestController < ActionController::Base
  class LabellingFormBuilder < ActionView::Helpers::FormBuilder
  end

  layout :determine_layout

  def hello_world
  end

  def conditional_hello
    if stale?(:last_modified => Time.now.utc.beginning_of_day, :etag => [:foo, 123])
      render :action => 'hello_world'
    end
  end

  def conditional_hello_with_bangs
    render :action => 'hello_world'
  end
  before_filter :handle_last_modified_and_etags, :only=>:conditional_hello_with_bangs
  
  def handle_last_modified_and_etags
    fresh_when(:last_modified => Time.now.utc.beginning_of_day, :etag => [ :foo, 123 ])
  end

  def render_hello_world
    render :template => "test/hello_world"
  end

  def render_hello_world_with_last_modified_set
    response.last_modified = Date.new(2008, 10, 10).to_time
    render :template => "test/hello_world"
  end

  def render_hello_world_with_etag_set
    response.etag = "hello_world"
    render :template => "test/hello_world"
  end

  def render_hello_world_with_forward_slash
    render :template => "/test/hello_world"
  end

  def render_template_in_top_directory
    render :template => 'shared'
  end

  def render_template_in_top_directory_with_slash
    render :template => '/shared'
  end

  def render_hello_world_from_variable
    @person = "david"
    render :text => "hello #{@person}"
  end

  def render_action_hello_world
    render :action => "hello_world"
  end

  def render_action_hello_world_with_symbol
    render :action => :hello_world
  end

  def render_text_hello_world
    render :text => "hello world"
  end

  def render_text_hello_world_with_layout
    @variable_for_layout = ", I'm here!"
    render :text => "hello world", :layout => true
  end

  def hello_world_with_layout_false
    render :layout => false
  end

  def render_file_with_instance_variables
    @secret = 'in the sauce'
    path = File.join(File.dirname(__FILE__), '../fixtures/test/render_file_with_ivar.erb')
    render :file => path
  end

  def render_file_not_using_full_path
    @secret = 'in the sauce'
    render :file => 'test/render_file_with_ivar'
  end

  def render_file_not_using_full_path_with_dot_in_path
    @secret = 'in the sauce'
    render :file => 'test/dot.directory/render_file_with_ivar'
  end

  def render_file_from_template
    @secret = 'in the sauce'
    @path = File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/test/render_file_with_ivar.erb'))
  end

  def render_file_with_locals
    path = File.join(File.dirname(__FILE__), '../fixtures/test/render_file_with_locals.erb')
    render :file => path, :locals => {:secret => 'in the sauce'}
  end

  def accessing_request_in_template
    render :inline =>  "Hello: <%= request.host %>"
  end

  def accessing_logger_in_template
    render :inline =>  "<%= logger.class %>"
  end

  def accessing_action_name_in_template
    render :inline =>  "<%= action_name %>"
  end

  def accessing_controller_name_in_template
    render :inline =>  "<%= controller_name %>"
  end

  def render_json_hello_world
    render :json => {:hello => 'world'}.to_json
  end

  def render_json_hello_world_with_callback
    render :json => {:hello => 'world'}.to_json, :callback => 'alert'
  end

  def render_json_with_custom_content_type
    render :json => {:hello => 'world'}.to_json, :content_type => 'text/javascript'
  end

  def render_symbol_json
    render :json => {:hello => 'world'}.to_json
  end

  def render_json_with_render_to_string
    render :json => {:hello => render_to_string(:partial => 'partial')}
  end

  def render_custom_code
    render :text => "hello world", :status => 404
  end

  def render_custom_code_rjs
    render :update, :status => 404 do |page|
      page.replace :foo, :partial => 'partial'
    end
  end

  def render_text_with_nil
    render :text => nil
  end

  def render_text_with_false
    render :text => false
  end

  def render_nothing_with_appendix
    render :text => "appended"
  end

  def render_invalid_args
    render("test/hello")
  end

  def render_vanilla_js_hello
    render :js => "alert('hello')"
  end

  def render_xml_hello
    @name = "David"
    render :template => "test/hello"
  end

  def render_xml_with_custom_content_type
    render :xml => "<blah/>", :content_type => "application/atomsvc+xml"
  end

  def render_line_offset
    render :inline => '<% raise %>', :locals => {:foo => 'bar'}
  end

  def heading
    head :ok
  end

  def greeting
    # let's just rely on the template
  end

  def layout_test
    render :action => "hello_world"
  end

  def builder_layout_test
    render :action => "hello", :layout => "layouts/builder"
  end

  def builder_partial_test
    render :action => "hello_world_container"
  end

  def partials_list
    @test_unchanged = 'hello'
    @customers = [ Customer.new("david"), Customer.new("mary") ]
    render :action => "list"
  end

  def partial_only
    render :partial => true
  end

  def hello_in_a_string
    @customers = [ Customer.new("david"), Customer.new("mary") ]
    render :text => "How's there? " + render_to_string(:template => "test/list")
  end

  def accessing_params_in_template
    render :inline => "Hello: <%= params[:name] %>"
  end

  def accessing_local_assigns_in_inline_template
    name = params[:local_name]
    render :inline => "<%= 'Goodbye, ' + local_name %>",
           :locals => { :local_name => name }
  end

  def formatted_html_erb
  end

  def formatted_xml_erb
  end

  def render_to_string_test
    @foo = render_to_string :inline => "this is a test"
  end

  def default_render
    if @alternate_default_render
      @alternate_default_render.call
    else
      super
    end
  end

  def render_action_hello_world_as_symbol
    render :action => :hello_world
  end

  def layout_test_with_different_layout
    render :action => "hello_world", :layout => "standard"
  end

  def rendering_without_layout
    render :action => "hello_world", :layout => false
  end

  def layout_overriding_layout
    render :action => "hello_world", :layout => "standard"
  end

  def rendering_nothing_on_layout
    render :nothing => true
  end

  def render_to_string_with_assigns
    @before = "i'm before the render"
    render_to_string :text => "foo"
    @after = "i'm after the render"
    render :action => "test/hello_world"
  end

  def render_to_string_with_exception
    render_to_string :file => "exception that will not be caught - this will certainly not work"
  end

  def render_to_string_with_caught_exception
    @before = "i'm before the render"
    begin
      render_to_string :file => "exception that will be caught- hope my future instance vars still work!"
    rescue
    end
    @after = "i'm after the render"
    render :action => "test/hello_world"
  end

  def accessing_params_in_template_with_layout
    render :layout => nil, :inline =>  "Hello: <%= params[:name] %>"
  end

  def render_with_explicit_template
    render :template => "test/hello_world"
  end

  def render_with_explicit_template_with_locals
    render :template => "test/render_file_with_locals", :locals => { :secret => 'area51' }
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

  def render_to_string_and_render
    @stuff = render_to_string :text => "here is some cached stuff"
    render :text => "Hi web users! #{@stuff}"
  end

  def rendering_with_conflicting_local_vars
    @name = "David"
    def @template.name() nil end
    render :action => "potential_conflicts"
  end

  def hello_world_from_rxml_using_action
    render :action => "hello_world_from_rxml.builder"
  end

  def hello_world_from_rxml_using_template
    render :template => "test/hello_world_from_rxml.builder"
  end

  module RenderTestHelper
    def rjs_helper_method_from_module
      page.visual_effect :highlight
    end
  end

  helper RenderTestHelper
  helper do
    def rjs_helper_method(value)
      page.visual_effect :highlight, value
    end
  end

  def enum_rjs_test
    render :update do |page|
      page.select('.product').each do |value|
        page.rjs_helper_method_from_module
        page.rjs_helper_method(value)
        page.sortable(value, :url => { :action => "order" })
        page.draggable(value)
      end
    end
  end

  def delete_with_js
    @project_id = 4
  end

  def render_js_with_explicit_template
    @project_id = 4
    render :template => 'test/delete_with_js'
  end

  def render_js_with_explicit_action_template
    @project_id = 4
    render :action => 'delete_with_js'
  end

  def update_page
    render :update do |page|
      page.replace_html 'balance', '$37,000,000.00'
      page.visual_effect :highlight, 'balance'
    end
  end

  def update_page_with_instance_variables
    @money = '$37,000,000.00'
    @div_id = 'balance'
    render :update do |page|
      page.replace_html @div_id, @money
      page.visual_effect :highlight, @div_id
    end
  end

  def update_page_with_view_method
    render :update do |page|
      page.replace_html 'person', pluralize(2, 'person')
    end
  end

  def action_talk_to_layout
    # Action template sets variable that's picked up by layout
  end

  def render_text_with_assigns
    @hello = "world"
    render :text => "foo"
  end

  def yield_content_for
    render :action => "content_for", :layout => "yield"
  end

  def render_content_type_from_body
    response.content_type = Mime::RSS
    render :text => "hello world!"
  end

  def head_with_location_header
    head :location => "/foo"
  end

  def head_with_symbolic_status
    head :status => params[:status].intern
  end

  def head_with_integer_status
    head :status => params[:status].to_i
  end

  def head_with_string_status
    head :status => params[:status]
  end

  def head_with_custom_header
    head :x_custom_header => "something"
  end

  def head_with_status_code_first
    head :forbidden, :x_custom_header => "something"
  end

  def render_with_location
    render :xml => "<hello/>", :location => "http://example.com", :status => 201
  end

  def render_with_object_location
    customer = Customer.new("Some guy", 1)
    render :xml => "<customer/>", :location => customer_url(customer), :status => :created
  end

  def render_with_to_xml
    to_xmlable = Class.new do
      def to_xml
        "<i-am-xml/>"
      end
    end.new

    render :xml => to_xmlable
  end

  def render_using_layout_around_block
    render :action => "using_layout_around_block"
  end

  def render_using_layout_around_block_with_args
    render :action => "using_layout_around_block_with_args"
  end

  def render_using_layout_around_block_in_main_layout_and_within_content_for_layout
    render :action => "using_layout_around_block", :layout => "layouts/block_with_layout"
  end

  def partial_dot_html
    render :partial => 'partial.html.erb'
  end

  def partial_as_rjs
    render :update do |page|
      page.replace :foo, :partial => 'partial'
    end
  end

  def respond_to_partial_as_rjs
    respond_to do |format|
      format.js do
        render :update do |page|
          page.replace :foo, :partial => 'partial'
        end
      end
    end
  end

  def partial
    render :partial => 'partial'
  end

  def render_alternate_default
    # For this test, the method "default_render" is overridden:
    @alternate_default_render = lambda do
      render :update do |page|
        page.replace :foo, :partial => 'partial'
      end
    end
  end

  def partial_only_with_layout
    render :partial => "partial_only", :layout => true
  end

  def render_to_string_with_partial
    @partial_only = render_to_string :partial => "partial_only"
    @partial_with_locals = render_to_string :partial => "customer", :locals => { :customer => Customer.new("david") }
    render :action => "test/hello_world"
  end

  def partial_with_counter
    render :partial => "counter", :locals => { :counter_counter => 5 }
  end

  def partial_with_locals
    render :partial => "customer", :locals => { :customer => Customer.new("david") }
  end

  def partial_with_form_builder
    render :partial => ActionView::Helpers::FormBuilder.new(:post, nil, @template, {}, Proc.new {})
  end

  def partial_with_form_builder_subclass
    render :partial => LabellingFormBuilder.new(:post, nil, @template, {}, Proc.new {})
  end

  def partial_collection
    render :partial => "customer", :collection => [ Customer.new("david"), Customer.new("mary") ]
  end

  def partial_collection_with_as
    render :partial => "customer_with_var", :collection => [ Customer.new("david"), Customer.new("mary") ], :as => :customer
  end

  def partial_collection_with_counter
    render :partial => "customer_counter", :collection => [ Customer.new("david"), Customer.new("mary") ]
  end

  def partial_collection_with_locals
    render :partial => "customer_greeting", :collection => [ Customer.new("david"), Customer.new("mary") ], :locals => { :greeting => "Bonjour" }
  end

  def partial_collection_with_spacer
    render :partial => "customer", :spacer_template => "partial_only", :collection => [ Customer.new("david"), Customer.new("mary") ]
  end

  def partial_collection_shorthand_with_locals
    render :partial => [ Customer.new("david"), Customer.new("mary") ], :locals => { :greeting => "Bonjour" }
  end

  def partial_collection_shorthand_with_different_types_of_records
    render :partial => [
        BadCustomer.new("mark"),
        GoodCustomer.new("craig"),
        BadCustomer.new("john"),
        GoodCustomer.new("zach"),
        GoodCustomer.new("brandon"),
        BadCustomer.new("dan") ],
      :locals => { :greeting => "Bonjour" }
  end

  def empty_partial_collection
    render :partial => "customer", :collection => []
  end

  def partial_collection_shorthand_with_different_types_of_records_with_counter
    partial_collection_shorthand_with_different_types_of_records
  end

  def missing_partial
    render :partial => 'thisFileIsntHere'
  end

  def partial_with_hash_object
    render :partial => "hash_object", :object => {:first_name => "Sam"}
  end

  def partial_hash_collection
    render :partial => "hash_object", :collection => [ {:first_name => "Pratik"}, {:first_name => "Amy"} ]
  end

  def partial_hash_collection_with_locals
    render :partial => "hash_greeting", :collection => [ {:first_name => "Pratik"}, {:first_name => "Amy"} ], :locals => { :greeting => "Hola" }
  end

  def partial_with_implicit_local_assignment
    @customer = Customer.new("Marcel")
    render :partial => "customer"
  end

  def render_call_to_partial_with_layout
    render :action => "calling_partial_with_layout"
  end

  def render_call_to_partial_with_layout_in_main_layout_and_within_content_for_layout
    render :action => "calling_partial_with_layout", :layout => "layouts/partial_with_layout"
  end

  def rescue_action(e)
    raise
  end

  private
    def determine_layout
      case action_name
        when "hello_world", "layout_test", "rendering_without_layout",
             "rendering_nothing_on_layout", "render_text_hello_world",
             "render_text_hello_world_with_layout",
             "hello_world_with_layout_false",
             "partial_only", "partial_only_with_layout",
             "accessing_params_in_template",
             "accessing_params_in_template_with_layout",
             "render_with_explicit_template",
             "render_js_with_explicit_template",
             "render_js_with_explicit_action_template",
             "delete_with_js", "update_page", "update_page_with_instance_variables"

          "layouts/standard"
        when "action_talk_to_layout", "layout_overriding_layout"
          "layouts/talk_from_action"
      end
    end
end

class RenderTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = TestController.new

    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = Logger.new(nil)

    @request.host = "www.nextangle.com"
  end

  def test_simple_show
    get :hello_world
    assert_response 200
    assert_response :success
    assert_template "test/hello_world"
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_renders_default_template_for_missing_action
    get :'hyphen-ated'
    assert_template 'test/hyphen-ated'
  end

  def test_render
    get :render_hello_world
    assert_template "test/hello_world"
  end

  def test_line_offset
    begin
      get :render_line_offset
      flunk "the action should have raised an exception"
    rescue RuntimeError => exc
      line = exc.backtrace.first
      assert(line =~ %r{:(\d+):})
      assert_equal "1", $1,
        "The line offset is wrong, perhaps the wrong exception has been raised, exception was: #{exc.inspect}"
    end
  end

  def test_render_with_forward_slash
    get :render_hello_world_with_forward_slash
    assert_template "test/hello_world"
  end

  def test_render_in_top_directory
    get :render_template_in_top_directory
    assert_template "shared"
    assert_equal "Elastica", @response.body
  end

  def test_render_in_top_directory_with_slash
    get :render_template_in_top_directory_with_slash
    assert_template "shared"
    assert_equal "Elastica", @response.body
  end

  def test_render_from_variable
    get :render_hello_world_from_variable
    assert_equal "hello david", @response.body
  end

  def test_render_action
    get :render_action_hello_world
    assert_template "test/hello_world"
  end

  def test_render_action_with_symbol
    get :render_action_hello_world_with_symbol
    assert_template "test/hello_world"
  end

  def test_render_text
    get :render_text_hello_world
    assert_equal "hello world", @response.body
  end

  def test_do_with_render_text_and_layout
    get :render_text_hello_world_with_layout
    assert_equal "<html>hello world, I'm here!</html>", @response.body
  end

  def test_do_with_render_action_and_layout_false
    get :hello_world_with_layout_false
    assert_equal 'Hello world!', @response.body
  end

  def test_render_file_with_instance_variables
    get :render_file_with_instance_variables
    assert_equal "The secret is in the sauce\n", @response.body
  end

  def test_render_file_not_using_full_path
    get :render_file_not_using_full_path
    assert_equal "The secret is in the sauce\n", @response.body
  end

  def test_render_file_not_using_full_path_with_dot_in_path
    get :render_file_not_using_full_path_with_dot_in_path
    assert_equal "The secret is in the sauce\n", @response.body
  end

  def test_render_file_with_locals
    get :render_file_with_locals
    assert_equal "The secret is in the sauce\n", @response.body
  end

  def test_render_file_from_template
    get :render_file_from_template
    assert_equal "The secret is in the sauce\n", @response.body
  end

  def test_render_json
    get :render_json_hello_world
    assert_equal '{"hello": "world"}', @response.body
    assert_equal 'application/json', @response.content_type
  end

  def test_render_json_with_callback
    get :render_json_hello_world_with_callback
    assert_equal 'alert({"hello": "world"})', @response.body
    assert_equal 'application/json', @response.content_type
  end

  def test_render_json_with_custom_content_type
    get :render_json_with_custom_content_type
    assert_equal '{"hello": "world"}', @response.body
    assert_equal 'text/javascript', @response.content_type
  end

  def test_render_symbol_json
    get :render_symbol_json
    assert_equal '{"hello": "world"}', @response.body
    assert_equal 'application/json', @response.content_type
  end

  def test_render_json_with_render_to_string
    get :render_json_with_render_to_string
    assert_equal '{"hello": "partial html"}', @response.body
    assert_equal 'application/json', @response.content_type
  end

  def test_render_custom_code
    get :render_custom_code
    assert_response 404
    assert_response :missing
    assert_equal 'hello world', @response.body
  end

  def test_render_custom_code_rjs
    get :render_custom_code_rjs
    assert_response 404
    assert_equal %(Element.replace("foo", "partial html");), @response.body
  end

  def test_render_text_with_nil
    get :render_text_with_nil
    assert_response 200
    assert_equal ' ', @response.body
  end

  def test_render_text_with_false
    get :render_text_with_false
    assert_equal 'false', @response.body
  end

  def test_render_nothing_with_appendix
    get :render_nothing_with_appendix
    assert_response 200
    assert_equal 'appended', @response.body
  end

  def test_attempt_to_render_with_invalid_arguments
    assert_raises(ActionController::RenderError) { get :render_invalid_args }
  end

  def test_attempt_to_access_object_method
    assert_raises(ActionController::UnknownAction, "No action responded to [clone]") { get :clone }
  end

  def test_private_methods
    assert_raises(ActionController::UnknownAction, "No action responded to [determine_layout]") { get :determine_layout }
  end

  def test_access_to_request_in_view
    get :accessing_request_in_template
    assert_equal "Hello: www.nextangle.com", @response.body
  end

  def test_access_to_logger_in_view
    get :accessing_logger_in_template
    assert_equal "Logger", @response.body
  end

  def test_access_to_action_name_in_view
    get :accessing_action_name_in_template
    assert_equal "accessing_action_name_in_template", @response.body
  end

  def test_access_to_controller_name_in_view
    get :accessing_controller_name_in_template
    assert_equal "test", @response.body # name is explicitly set to 'test' inside the controller.
  end

  def test_render_vanilla_js
    get :render_vanilla_js_hello
    assert_equal "alert('hello')", @response.body
    assert_equal "text/javascript", @response.content_type
  end

  def test_render_xml
    get :render_xml_hello
    assert_equal "<html>\n  <p>Hello David</p>\n<p>This is grand!</p>\n</html>\n", @response.body
    assert_equal "application/xml", @response.content_type
  end

  def test_render_xml_with_default
    get :greeting
    assert_equal "<p>This is grand!</p>\n", @response.body
  end

  def test_render_xml_with_partial
    get :builder_partial_test
    assert_equal "<test>\n  <hello/>\n</test>\n", @response.body
  end

  def test_enum_rjs_test
    get :enum_rjs_test
    body = %{
      $$(".product").each(function(value, index) {
      new Effect.Highlight(element,{});
      new Effect.Highlight(value,{});
      Sortable.create(value, {onUpdate:function(){new Ajax.Request('/test/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize(value)})}});
      new Draggable(value, {});
      });
    }.gsub(/^      /, '').strip
    assert_equal body, @response.body
  end

  def test_layout_rendering
    get :layout_test
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_render_xml_with_layouts
    get :builder_layout_test
    assert_equal "<wrapper>\n<html>\n  <p>Hello </p>\n<p>This is grand!</p>\n</html>\n</wrapper>\n", @response.body
  end

  def test_partials_list
    get :partials_list
    assert_equal "goodbyeHello: davidHello: marygoodbye\n", @response.body
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

  def test_should_render_formatted_template
    get :formatted_html_erb
    assert_equal 'formatted html erb', @response.body
  end

  def test_should_render_formatted_xml_erb_template
    get :formatted_xml_erb, :format => :xml
    assert_equal '<test>passed formatted xml erb</test>', @response.body
  end

  def test_should_render_formatted_html_erb_template
    get :formatted_xml_erb
    assert_equal '<test>passed formatted html erb</test>', @response.body
  end

  def test_should_render_formatted_html_erb_template_with_faulty_accepts_header
    @request.accept = "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, appliction/x-shockwave-flash, */*"
    get :formatted_xml_erb
    assert_equal '<test>passed formatted html erb</test>', @response.body
  end

  def test_should_render_xml_but_keep_custom_content_type
    get :render_xml_with_custom_content_type
    assert_equal "application/atomsvc+xml", @response.content_type
  end

  def test_render_with_default_from_accept_header
    xhr :get, :greeting
    assert_equal "$(\"body\").visualEffect(\"highlight\");", @response.body
  end

  def test_render_rjs_with_default
    get :delete_with_js
    assert_equal %!Element.remove("person");\nnew Effect.Highlight(\"project-4\",{});!, @response.body
  end

  def test_render_rjs_template_explicitly
    get :render_js_with_explicit_template
    assert_equal %!Element.remove("person");\nnew Effect.Highlight(\"project-4\",{});!, @response.body
  end

  def test_rendering_rjs_action_explicitly
    get :render_js_with_explicit_action_template
    assert_equal %!Element.remove("person");\nnew Effect.Highlight(\"project-4\",{});!, @response.body
  end

  def test_layout_test_with_different_layout
    get :layout_test_with_different_layout
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_rendering_without_layout
    get :rendering_without_layout
    assert_equal "Hello world!", @response.body
  end

  def test_layout_overriding_layout
    get :layout_overriding_layout
    assert_no_match %r{<title>}, @response.body
  end

  def test_rendering_nothing_on_layout
    get :rendering_nothing_on_layout
    assert_equal " ", @response.body
  end

  def test_render_to_string
    assert_not_deprecated { get :hello_in_a_string }
    assert_equal "How's there? goodbyeHello: davidHello: marygoodbye\n", @response.body
  end

  def test_render_to_string_doesnt_break_assigns
    get :render_to_string_with_assigns
    assert_equal "i'm before the render", assigns(:before)
    assert_equal "i'm after the render", assigns(:after)
  end

  def test_bad_render_to_string_still_throws_exception
    assert_raises(ActionView::MissingTemplate) { get :render_to_string_with_exception }
  end

  def test_render_to_string_that_throws_caught_exception_doesnt_break_assigns
    assert_nothing_raised { get :render_to_string_with_caught_exception }
    assert_equal "i'm before the render", assigns(:before)
    assert_equal "i'm after the render", assigns(:after)
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

  # specify the one exception to double render rule - render_to_string followed by render
  def test_render_to_string_and_render
    get :render_to_string_and_render
    assert_equal("Hi web users! here is some cached stuff", @response.body)
  end

  def test_rendering_with_conflicting_local_vars
    get :rendering_with_conflicting_local_vars
    assert_equal("First: David\nSecond: Stephan\nThird: David\nFourth: David\nFifth: ", @response.body)
  end

  def test_action_talk_to_layout
    get :action_talk_to_layout
    assert_equal "<title>Talking to the layout</title>\nAction was here!", @response.body
  end

  def test_render_text_with_assigns
    get :render_text_with_assigns
    assert_equal "world", assigns["hello"]
  end

  def test_template_with_locals
    get :render_with_explicit_template_with_locals
    assert_equal "The secret is area51\n", @response.body
  end

  def test_update_page
    get :update_page
    assert_template nil
    assert_equal 'text/javascript; charset=utf-8', @response.headers['type']
    assert_equal 2, @response.body.split($/).length
  end

  def test_update_page_with_instance_variables
    get :update_page_with_instance_variables
    assert_template nil
    assert_equal 'text/javascript; charset=utf-8', @response.headers['type']
    assert_match /balance/, @response.body
    assert_match /\$37/, @response.body
  end

  def test_update_page_with_view_method
    get :update_page_with_view_method
    assert_template nil
    assert_equal 'text/javascript; charset=utf-8', @response.headers['type']
    assert_match /2 people/, @response.body
  end

  def test_yield_content_for
    assert_not_deprecated { get :yield_content_for }
    assert_equal "<title>Putting stuff in the title!</title>\n\nGreat stuff!\n", @response.body
  end

  def test_overwritting_rendering_relative_file_with_extension
    get :hello_world_from_rxml_using_template
    assert_equal "<html>\n  <p>Hello</p>\n</html>\n", @response.body

    get :hello_world_from_rxml_using_action
    assert_equal "<html>\n  <p>Hello</p>\n</html>\n", @response.body
  end

  def test_head_with_location_header
    get :head_with_location_header
    assert @response.body.blank?
    assert_equal "/foo", @response.headers["Location"]
    assert_response :ok
  end

  def test_head_with_custom_header
    get :head_with_custom_header
    assert @response.body.blank?
    assert_equal "something", @response.headers["X-Custom-Header"]
    assert_response :ok
  end

  def test_head_with_symbolic_status
    get :head_with_symbolic_status, :status => "ok"
    assert_equal "200 OK", @response.headers["Status"]
    assert_response :ok

    get :head_with_symbolic_status, :status => "not_found"
    assert_equal "404 Not Found", @response.headers["Status"]
    assert_response :not_found

    ActionController::StatusCodes::SYMBOL_TO_STATUS_CODE.each do |status, code|
      get :head_with_symbolic_status, :status => status.to_s
      assert_equal code, @response.response_code
      assert_response status
    end
  end

  def test_head_with_integer_status
    ActionController::StatusCodes::STATUS_CODES.each do |code, message|
      get :head_with_integer_status, :status => code.to_s
      assert_equal message, @response.message
    end
  end

  def test_head_with_string_status
    get :head_with_string_status, :status => "404 Eat Dirt"
    assert_equal 404, @response.response_code
    assert_equal "Eat Dirt", @response.message
    assert_response :not_found
  end

  def test_head_with_status_code_first
    get :head_with_status_code_first
    assert_equal 403, @response.response_code
    assert_equal "Forbidden", @response.message
    assert_equal "something", @response.headers["X-Custom-Header"]
    assert_response :forbidden
  end

  def test_rendering_with_location_should_set_header
    get :render_with_location
    assert_equal "http://example.com", @response.headers["Location"]
  end

  def test_rendering_xml_should_call_to_xml_if_possible
    get :render_with_to_xml
    assert_equal "<i-am-xml/>", @response.body
  end

  def test_rendering_with_object_location_should_set_header_with_url_for
    ActionController::Routing::Routes.draw do |map|
      map.resources :customers
      map.connect ':controller/:action/:id'
    end

    get :render_with_object_location
    assert_equal "http://www.nextangle.com/customers/1", @response.headers["Location"]
  end

  def test_should_use_implicit_content_type
    get :implicit_content_type, :format => 'atom'
    assert_equal Mime::ATOM, @response.content_type
  end

  def test_using_layout_around_block
    get :render_using_layout_around_block
    assert_equal "Before (David)\nInside from block\nAfter", @response.body
  end

  def test_using_layout_around_block_in_main_layout_and_within_content_for_layout
    get :render_using_layout_around_block_in_main_layout_and_within_content_for_layout
    assert_equal "Before (Anthony)\nInside from first block in layout\nAfter\nBefore (David)\nInside from block\nAfter\nBefore (Ramm)\nInside from second block in layout\nAfter\n", @response.body
  end

  def test_using_layout_around_block_with_args
    get :render_using_layout_around_block_with_args
    assert_equal "Before\narg1arg2\nAfter", @response.body
  end

  def test_partial_only
    get :partial_only
    assert_equal "only partial", @response.body
  end

  def test_should_render_html_formatted_partial
    get :partial
    assert_equal 'partial html', @response.body
  end

  def test_should_render_html_partial_with_dot
    get :partial_dot_html
    assert_equal 'partial html', @response.body
  end

  def test_should_render_html_formatted_partial_with_rjs
    xhr :get, :partial_as_rjs
    assert_equal %(Element.replace("foo", "partial html");), @response.body
  end

  def test_should_render_html_formatted_partial_with_rjs_and_js_format
    xhr :get, :respond_to_partial_as_rjs
    assert_equal %(Element.replace("foo", "partial html");), @response.body
  end

  def test_should_render_js_partial
    xhr :get, :partial, :format => 'js'
    assert_equal 'partial js', @response.body
  end

  def test_should_render_with_alternate_default_render
    xhr :get, :render_alternate_default
    assert_equal %(Element.replace("foo", "partial html");), @response.body
  end

  def test_partial_only_with_layout
    get :partial_only_with_layout
    assert_equal "<html>only partial</html>", @response.body
  end

  def test_render_to_string_partial
    get :render_to_string_with_partial
    assert_equal "only partial", assigns(:partial_only)
    assert_equal "Hello: david", assigns(:partial_with_locals)
  end

  def test_partial_with_counter
    get :partial_with_counter
    assert_equal "5", @response.body
  end

  def test_partial_with_locals
    get :partial_with_locals
    assert_equal "Hello: david", @response.body
  end

  def test_partial_with_form_builder
    get :partial_with_form_builder
    assert_match(/<label/, @response.body)
    assert_template('test/_form')
  end

  def test_partial_with_form_builder_subclass
    get :partial_with_form_builder_subclass
    assert_match(/<label/, @response.body)
    assert_template('test/_labelling_form')
  end

  def test_partial_collection
    get :partial_collection
    assert_equal "Hello: davidHello: mary", @response.body
  end

  def test_partial_collection_with_as
    get :partial_collection_with_as
    assert_equal "david david davidmary mary mary", @response.body
  end

  def test_partial_collection_with_counter
    get :partial_collection_with_counter
    assert_equal "david0mary1", @response.body
  end

  def test_partial_collection_with_locals
    get :partial_collection_with_locals
    assert_equal "Bonjour: davidBonjour: mary", @response.body
  end

  def test_partial_collection_with_spacer
    get :partial_collection_with_spacer
    assert_equal "Hello: davidonly partialHello: mary", @response.body
  end

  def test_partial_collection_shorthand_with_locals
    get :partial_collection_shorthand_with_locals
    assert_equal "Bonjour: davidBonjour: mary", @response.body
  end

  def test_partial_collection_shorthand_with_different_types_of_records
    get :partial_collection_shorthand_with_different_types_of_records
    assert_equal "Bonjour bad customer: mark0Bonjour good customer: craig1Bonjour bad customer: john2Bonjour good customer: zach3Bonjour good customer: brandon4Bonjour bad customer: dan5", @response.body
  end

  def test_empty_partial_collection
    get :empty_partial_collection
    assert_equal " ", @response.body
  end

  def test_partial_with_hash_object
    get :partial_with_hash_object
    assert_equal "Sam\nmaS\n", @response.body
  end

  def test_hash_partial_collection
    get :partial_hash_collection
    assert_equal "Pratik\nkitarP\nAmy\nymA\n", @response.body
  end

  def test_partial_hash_collection_with_locals
    get :partial_hash_collection_with_locals
    assert_equal "Hola: PratikHola: Amy", @response.body
  end

  def test_partial_with_implicit_local_assignment
    assert_deprecated do
      get :partial_with_implicit_local_assignment
      assert_equal "Hello: Marcel", @response.body
    end
  end

  def test_render_missing_partial_template
    assert_raises(ActionView::MissingTemplate) do
      get :missing_partial
    end
  end

  def test_render_call_to_partial_with_layout
    get :render_call_to_partial_with_layout
    assert_equal "Before (David)\nInside from partial (David)\nAfter", @response.body
  end

  def test_render_call_to_partial_with_layout_in_main_layout_and_within_content_for_layout
    get :render_call_to_partial_with_layout_in_main_layout_and_within_content_for_layout
    assert_equal "Before (Anthony)\nInside from partial (Anthony)\nAfter\nBefore (David)\nInside from partial (David)\nAfter\nBefore (Ramm)\nInside from partial (Ramm)\nAfter", @response.body
  end
end

class EtagRenderTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = TestController.new

    @request.host = "www.nextangle.com"
    @expected_bang_etag = etag_for(expand_key([:foo, 123]))
  end

  def test_render_200_should_set_etag
    get :render_hello_world_from_variable
    assert_equal etag_for("hello david"), @response.headers['ETag']
    assert_equal "private, max-age=0, must-revalidate", @response.headers['Cache-Control']
  end

  def test_render_against_etag_request_should_304_when_match
    @request.if_none_match = etag_for("hello david")
    get :render_hello_world_from_variable
    assert_equal "304 Not Modified", @response.status
    assert @response.body.empty?
  end

  def test_render_against_etag_request_should_have_no_content_length_when_match
    @request.if_none_match = etag_for("hello david")
    get :render_hello_world_from_variable
    assert !@response.headers.has_key?("Content-Length")
  end

  def test_render_against_etag_request_should_200_when_no_match
    @request.if_none_match = etag_for("hello somewhere else")
    get :render_hello_world_from_variable
    assert_equal "200 OK", @response.status
    assert !@response.body.empty?
  end
  
  def test_render_should_not_set_etag_when_last_modified_has_been_specified
    get :render_hello_world_with_last_modified_set
    assert_equal "200 OK", @response.status
    assert_not_nil @response.last_modified
    assert_nil @response.etag
    assert @response.body.present?
  end

  def test_render_with_etag
    get :render_hello_world_from_variable
    expected_etag = etag_for('hello david')
    assert_equal expected_etag, @response.headers['ETag']
    @response = ActionController::TestResponse.new
    
    @request.if_none_match = expected_etag
    get :render_hello_world_from_variable
    assert_equal "304 Not Modified", @response.status

    @request.if_none_match = "\"diftag\""
    get :render_hello_world_from_variable
    assert_equal "200 OK", @response.status
  end

  def render_with_404_shouldnt_have_etag
    get :render_custom_code
    assert_nil @response.headers['ETag']
  end

  def test_etag_should_not_be_changed_when_already_set
    get :render_hello_world_with_etag_set
    assert_equal etag_for("hello_world"), @response.headers['ETag']
  end

  def test_etag_should_govern_renders_with_layouts_too
    get :builder_layout_test
    assert_equal "<wrapper>\n<html>\n  <p>Hello </p>\n<p>This is grand!</p>\n</html>\n</wrapper>\n", @response.body
    assert_equal etag_for("<wrapper>\n<html>\n  <p>Hello </p>\n<p>This is grand!</p>\n</html>\n</wrapper>\n"), @response.headers['ETag']
  end
  
  def test_etag_with_bang_should_set_etag
    get :conditional_hello_with_bangs
    assert_equal @expected_bang_etag, @response.headers["ETag"]
    assert_response :success
  end
  
  def test_etag_with_bang_should_obey_if_none_match
    @request.if_none_match = @expected_bang_etag
    get :conditional_hello_with_bangs
    assert_response :not_modified
  end
  
  protected
    def etag_for(text)
      %("#{Digest::MD5.hexdigest(text)}")
    end
    
    def expand_key(args)
      ActiveSupport::Cache.expand_cache_key(args)
    end
end

class LastModifiedRenderTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = TestController.new

    @request.host = "www.nextangle.com"
    @last_modified = Time.now.utc.beginning_of_day.httpdate
  end

  def test_responds_with_last_modified
    get :conditional_hello
    assert_equal @last_modified, @response.headers['Last-Modified']
  end

  def test_request_not_modified
    @request.if_modified_since = @last_modified
    get :conditional_hello
    assert_equal "304 Not Modified", @response.status
    assert @response.body.blank?, @response.body
    assert_equal @last_modified, @response.headers['Last-Modified']
  end

  def test_request_not_modified_but_etag_differs
    @request.if_modified_since = @last_modified
    @request.if_none_match = "234"
    get :conditional_hello
    assert_response :success
  end

  def test_request_modified
    @request.if_modified_since = 'Thu, 16 Jul 2008 00:00:00 GMT'
    get :conditional_hello
    assert_equal "200 OK", @response.status
    assert !@response.body.blank?
    assert_equal @last_modified, @response.headers['Last-Modified']
  end
  
  def test_request_with_bang_gets_last_modified
    get :conditional_hello_with_bangs
    assert_equal @last_modified, @response.headers['Last-Modified']
    assert_response :success
  end
  
  def test_request_with_bang_obeys_last_modified
    @request.if_modified_since = @last_modified
    get :conditional_hello_with_bangs
    assert_response :not_modified
  end

  def test_last_modified_works_with_less_than_too
    @request.if_modified_since = 5.years.ago.httpdate
    get :conditional_hello_with_bangs
    assert_response :success
  end
end

class RenderingLoggingTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = TestController.new

    @request.host = "www.nextangle.com"
  end

  def test_logger_prints_layout_and_template_rendering_info
    @controller.logger = MockLogger.new
    get :layout_test
    logged = @controller.logger.logged.find_all {|l| l =~ /render/i }
    assert_equal "Rendering template within layouts/standard", logged[0]
    assert_equal "Rendering test/hello_world", logged[1]
  end
end
