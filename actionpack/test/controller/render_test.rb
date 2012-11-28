require 'abstract_unit'
require 'controller/fake_models'
require 'pathname'

module Fun
  class GamesController < ActionController::Base
    # :ported:
    def hello_world
    end

    def nested_partial_with_form_builder
      render :partial => ActionView::Helpers::FormBuilder.new(:post, nil, view_context, {})
    end
  end
end

module Quiz
  class QuestionsController < ActionController::Base
    def new
      render :partial => Quiz::Question.new("Namespaced Partial")
    end
  end
end

class TestControllerWithExtraEtags < ActionController::Base
  etag { nil  }
  etag { 'ab' }
  etag { :cde }
  etag { [:f] }
  etag { nil  }

  def fresh
    render text: "stale" if stale?(etag: '123')
  end
end

class TestController < ActionController::Base
  protect_from_forgery

  before_filter :set_variable_for_layout

  class LabellingFormBuilder < ActionView::Helpers::FormBuilder
  end

  layout :determine_layout

  def name
    nil
  end

  private :name
  helper_method :name

  def hello_world
  end

  def hello_world_file
    render :file => File.expand_path("../../fixtures/hello", __FILE__), :formats => [:html]
  end

  def conditional_hello
    if stale?(:last_modified => Time.now.utc.beginning_of_day, :etag => [:foo, 123])
      render :action => 'hello_world'
    end
  end

  def conditional_hello_with_record
    record = Struct.new(:updated_at, :cache_key).new(Time.now.utc.beginning_of_day, "foo/123")

    if stale?(record)
      render :action => 'hello_world'
    end
  end

  def conditional_hello_with_public_header
    if stale?(:last_modified => Time.now.utc.beginning_of_day, :etag => [:foo, 123], :public => true)
      render :action => 'hello_world'
    end
  end

  def conditional_hello_with_public_header_with_record
    record = Struct.new(:updated_at, :cache_key).new(Time.now.utc.beginning_of_day, "foo/123")

    if stale?(record, :public => true)
      render :action => 'hello_world'
    end
  end

  def conditional_hello_with_public_header_and_expires_at
    expires_in 1.minute
    if stale?(:last_modified => Time.now.utc.beginning_of_day, :etag => [:foo, 123], :public => true)
      render :action => 'hello_world'
    end
  end

  def conditional_hello_with_expires_in
    expires_in 60.1.seconds
    render :action => 'hello_world'
  end

  def conditional_hello_with_expires_in_with_public
    expires_in 1.minute, :public => true
    render :action => 'hello_world'
  end

  def conditional_hello_with_expires_in_with_must_revalidate
    expires_in 1.minute, :must_revalidate => true
    render :action => 'hello_world'
  end

  def conditional_hello_with_expires_in_with_public_and_must_revalidate
    expires_in 1.minute, :public => true, :must_revalidate => true
    render :action => 'hello_world'
  end

  def conditional_hello_with_expires_in_with_public_with_more_keys
    expires_in 1.minute, :public => true, 's-maxage' => 5.hours
    render :action => 'hello_world'
  end

  def conditional_hello_with_expires_in_with_public_with_more_keys_old_syntax
    expires_in 1.minute, :public => true, :private => nil, 's-maxage' => 5.hours
    render :action => 'hello_world'
  end

  def conditional_hello_with_expires_now
    expires_now
    render :action => 'hello_world'
  end

  def conditional_hello_with_cache_control_headers
    response.headers['Cache-Control'] = 'no-transform'
    expires_now
    render :action => 'hello_world'
  end

  def conditional_hello_with_bangs
    render :action => 'hello_world'
  end
  before_filter :handle_last_modified_and_etags, :only=>:conditional_hello_with_bangs

  def handle_last_modified_and_etags
    fresh_when(:last_modified => Time.now.utc.beginning_of_day, :etag => [ :foo, 123 ])
  end

  # :ported:
  def render_hello_world
    render :template => "test/hello_world"
  end

  def render_hello_world_with_last_modified_set
    response.last_modified = Date.new(2008, 10, 10).to_time
    render :template => "test/hello_world"
  end

  # :ported: compatibility
  def render_hello_world_with_forward_slash
    render :template => "/test/hello_world"
  end

  # :ported:
  def render_template_in_top_directory
    render :template => 'shared'
  end

  # :deprecated:
  def render_template_in_top_directory_with_slash
    render :template => '/shared'
  end

  # :ported:
  def render_hello_world_from_variable
    @person = "david"
    render :text => "hello #{@person}"
  end

  # :ported:
  def render_action_hello_world
    render :action => "hello_world"
  end

  def render_action_upcased_hello_world
    render :action => "Hello_world"
  end

  def render_action_hello_world_as_string
    render "hello_world"
  end

  def render_action_hello_world_with_symbol
    render :action => :hello_world
  end

  # :ported:
  def render_text_hello_world
    render :text => "hello world"
  end

  # :ported:
  def render_text_hello_world_with_layout
    @variable_for_layout = ", I am here!"
    render :text => "hello world", :layout => true
  end

  def hello_world_with_layout_false
    render :layout => false
  end

  # :ported:
  def render_file_with_instance_variables
    @secret = 'in the sauce'
    path = File.join(File.dirname(__FILE__), '../fixtures/test/render_file_with_ivar')
    render :file => path
  end

  # :ported:
  def render_file_as_string_with_instance_variables
    @secret = 'in the sauce'
    path = File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/test/render_file_with_ivar'))
    render path
  end

  # :ported:
  def render_file_not_using_full_path
    @secret = 'in the sauce'
    render :file => 'test/render_file_with_ivar'
  end

  def render_file_not_using_full_path_with_dot_in_path
    @secret = 'in the sauce'
    render :file => 'test/dot.directory/render_file_with_ivar'
  end

  def render_file_using_pathname
    @secret = 'in the sauce'
    render :file => Pathname.new(File.dirname(__FILE__)).join('..', 'fixtures', 'test', 'dot.directory', 'render_file_with_ivar')
  end

  def render_file_from_template
    @secret = 'in the sauce'
    @path = File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/test/render_file_with_ivar'))
  end

  def render_file_with_locals
    path = File.join(File.dirname(__FILE__), '../fixtures/test/render_file_with_locals')
    render :file => path, :locals => {:secret => 'in the sauce'}
  end

  def render_file_as_string_with_locals
    path = File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/test/render_file_with_locals'))
    render path, :locals => {:secret => 'in the sauce'}
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

  # :ported:
  def render_custom_code
    render :text => "hello world", :status => 404
  end

  # :ported:
  def render_text_with_nil
    render :text => nil
  end

  # :ported:
  def render_text_with_false
    render :text => false
  end

  def render_text_with_resource
    render :text => Customer.new("David")
  end

  # :ported:
  def render_nothing_with_appendix
    render :text => "appended"
  end

  # This test is testing 3 things:
  #   render :file in AV      :ported:
  #   render :template in AC  :ported:
  #   setting content type
  def render_xml_hello
    @name = "David"
    render :template => "test/hello"
  end

  def render_xml_hello_as_string_template
    @name = "David"
    render "test/hello"
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

  # :ported:
  def blank_response
    render :text => ' '
  end

  # :ported:
  def layout_test
    render :action => "hello_world"
  end

  # :ported:
  def builder_layout_test
    @name = nil
    render :action => "hello", :layout => "layouts/builder"
  end

  # :move: test this in Action View
  def builder_partial_test
    render :action => "hello_world_container"
  end

  # :ported:
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

  def render_implicit_html_template_from_xhr_request
  end

  def render_implicit_js_template_without_layout
  end

  def formatted_html_erb
  end

  def formatted_xml_erb
  end

  def render_to_string_test
    @foo = render_to_string :inline => "this is a test"
  end

  def default_render
    @alternate_default_render ||= nil
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

  def layout_test_with_different_layout_and_string_action
    render "hello_world", :layout => "standard"
  end

  def layout_test_with_different_layout_and_symbol_action
    render :hello_world, :layout => "standard"
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
    render :template => "test/hello_world"
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
    render :template => "test/hello_world"
  end

  def accessing_params_in_template_with_layout
    render :layout => true, :inline =>  "Hello: <%= params[:name] %>"
  end

  # :ported:
  def render_with_explicit_template
    render :template => "test/hello_world"
  end

  def render_with_explicit_unescaped_template
    render :template => "test/h*llo_world"
  end

  def render_with_explicit_escaped_template
    render :template => "test/hello,world"
  end

  def render_with_explicit_string_template
    render "test/hello_world"
  end

  # :ported:
  def render_with_explicit_template_with_locals
    render :template => "test/render_file_with_locals", :locals => { :secret => 'area51' }
  end

  # :ported:
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

  def render_to_string_with_inline_and_render
    render_to_string :inline => "<%= 'dlrow olleh'.reverse %>"
    render :template => "test/hello_world"
  end

  def rendering_with_conflicting_local_vars
    @name = "David"
    render :action => "potential_conflicts"
  end

  def hello_world_from_rxml_using_action
    render :action => "hello_world_from_rxml", :handlers => [:builder]
  end

  # :deprecated:
  def hello_world_from_rxml_using_template
    render :template => "test/hello_world_from_rxml", :handlers => [:builder]
  end

  def action_talk_to_layout
    # Action template sets variable that's picked up by layout
  end

  # :addressed:
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

  def head_created
    head :created
  end

  def head_created_with_application_json_content_type
    head :created, :content_type => "application/json"
  end

  def head_with_location_header
    head :location => "/foo"
  end

  def head_with_location_object
    head :location => Customer.new("david", 1)
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

  def head_with_www_authenticate_header
    head 'WWW-Authenticate' => 'something'
  end

  def head_with_status_code_first
    head :forbidden, :x_custom_header => "something"
  end

  def render_using_layout_around_block
    render :action => "using_layout_around_block"
  end

  def render_using_layout_around_block_in_main_layout_and_within_content_for_layout
    render :action => "using_layout_around_block", :layout => "layouts/block_with_layout"
  end

  def partial_formats_html
    render :partial => 'partial', :formats => [:html]
  end

  def partial
    render :partial => 'partial'
  end

  def partial_html_erb
    render :partial => 'partial_html_erb'
  end

  def render_to_string_with_partial
    @partial_only = render_to_string :partial => "partial_only"
    @partial_with_locals = render_to_string :partial => "customer", :locals => { :customer => Customer.new("david") }
    render :template => "test/hello_world"
  end

  def render_to_string_with_template_and_html_partial
    @text = render_to_string :template => "test/with_partial", :formats => [:text]
    @html = render_to_string :template => "test/with_partial", :formats => [:html]
    render :template => "test/with_html_partial"
  end

  def render_to_string_and_render_with_different_formats
    @html = render_to_string :template => "test/with_partial", :formats => [:html]
    render :template => "test/with_partial", :formats => [:text]
  end

  def render_template_within_a_template_with_other_format
    render  :template => "test/with_xml_template",
            :formats  => [:html],
            :layout   => "with_html_partial"
  end

  def partial_with_counter
    render :partial => "counter", :locals => { :counter_counter => 5 }
  end

  def partial_with_locals
    render :partial => "customer", :locals => { :customer => Customer.new("david") }
  end

  def partial_with_form_builder
    render :partial => ActionView::Helpers::FormBuilder.new(:post, nil, view_context, {})
  end

  def partial_with_form_builder_subclass
    render :partial => LabellingFormBuilder.new(:post, nil, view_context, {})
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

  def partial_collection_with_as_and_counter
    render :partial => "customer_counter_with_as", :collection => [ Customer.new("david"), Customer.new("mary") ], :as => :client
  end

  def partial_collection_with_locals
    render :partial => "customer_greeting", :collection => [ Customer.new("david"), Customer.new("mary") ], :locals => { :greeting => "Bonjour" }
  end

  def partial_collection_with_spacer
    render :partial => "customer", :spacer_template => "partial_only", :collection => [ Customer.new("david"), Customer.new("mary") ]
  end

  def partial_collection_with_spacer_which_uses_render
    render :partial => "customer", :spacer_template => "partial_with_partial", :collection => [ Customer.new("david"), Customer.new("mary") ]
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

  def partial_with_nested_object
    render :partial => "quiz/questions/question", :object => Quiz::Question.new("first")
  end

  def partial_with_nested_object_shorthand
    render Quiz::Question.new("first")
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

  before_filter :only => :render_with_filters do
    request.format = :xml
  end

  # Ensure that the before filter is executed *before* self.formats is set.
  def render_with_filters
    render :action => :formatted_xml_erb
  end

  private

    def set_variable_for_layout
      @variable_for_layout = nil
    end

    def determine_layout
      case action_name
        when "hello_world", "layout_test", "rendering_without_layout",
             "rendering_nothing_on_layout", "render_text_hello_world",
             "render_text_hello_world_with_layout",
             "hello_world_with_layout_false",
             "partial_only", "accessing_params_in_template",
             "accessing_params_in_template_with_layout",
             "render_with_explicit_template",
             "render_with_explicit_string_template",
             "update_page", "update_page_with_instance_variables"

          "layouts/standard"
        when "action_talk_to_layout", "layout_overriding_layout"
          "layouts/talk_from_action"
        when "render_implicit_html_template_from_xhr_request"
          (request.xhr? ? 'layouts/xhr' : 'layouts/standard')
      end
    end
end

class MetalTestController < ActionController::Metal
  include ActionController::Rendering

  def accessing_logger_in_template
    render :inline =>  "<%= logger.class %>"
  end
end

class RenderTest < ActionController::TestCase
  tests TestController

  def setup
    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    super
    @controller.logger      = ActiveSupport::Logger.new(nil)
    ActionView::Base.logger = ActiveSupport::Logger.new(nil)

    @request.host = "www.nextangle.com"
  end

  # :ported:
  def test_simple_show
    get :hello_world
    assert_response 200
    assert_response :success
    assert_template "test/hello_world"
    assert_equal "<html>Hello world!</html>", @response.body
  end

  # :ported:
  def test_renders_default_template_for_missing_action
    get :'hyphen-ated'
    assert_template 'test/hyphen-ated'
  end

  # :ported:
  def test_render
    get :render_hello_world
    assert_template "test/hello_world"
  end

  def test_line_offset
    begin
      get :render_line_offset
      flunk "the action should have raised an exception"
    rescue StandardError => exc
      line = exc.backtrace.first
      assert(line =~ %r{:(\d+):})
      assert_equal "1", $1,
        "The line offset is wrong, perhaps the wrong exception has been raised, exception was: #{exc.inspect}"
    end
  end

  # :ported: compatibility
  def test_render_with_forward_slash
    get :render_hello_world_with_forward_slash
    assert_template "test/hello_world"
  end

  # :ported:
  def test_render_in_top_directory
    get :render_template_in_top_directory
    assert_template "shared"
    assert_equal "Elastica", @response.body
  end

  # :ported:
  def test_render_in_top_directory_with_slash
    get :render_template_in_top_directory_with_slash
    assert_template "shared"
    assert_equal "Elastica", @response.body
  end

  # :ported:
  def test_render_from_variable
    get :render_hello_world_from_variable
    assert_equal "hello david", @response.body
  end

  # :ported:
  def test_render_action
    get :render_action_hello_world
    assert_template "test/hello_world"
  end

  def test_render_action_upcased
    assert_raise ActionView::MissingTemplate do
      get :render_action_upcased_hello_world
    end
  end

  # :ported:
  def test_render_action_hello_world_as_string
    get :render_action_hello_world_as_string
    assert_equal "Hello world!", @response.body
    assert_template "test/hello_world"
  end

  # :ported:
  def test_render_action_with_symbol
    get :render_action_hello_world_with_symbol
    assert_template "test/hello_world"
  end

  # :ported:
  def test_render_text
    get :render_text_hello_world
    assert_equal "hello world", @response.body
  end

  # :ported:
  def test_do_with_render_text_and_layout
    get :render_text_hello_world_with_layout
    assert_equal "<html>hello world, I am here!</html>", @response.body
  end

  # :ported:
  def test_do_with_render_action_and_layout_false
    get :hello_world_with_layout_false
    assert_equal 'Hello world!', @response.body
  end

  # :ported:
  def test_render_file_with_instance_variables
    get :render_file_with_instance_variables
    assert_equal "The secret is in the sauce\n", @response.body
  end

  def test_render_file
    get :hello_world_file
    assert_equal "Hello world!", @response.body
  end

  # :ported:
  def test_render_file_as_string_with_instance_variables
    get :render_file_as_string_with_instance_variables
    assert_equal "The secret is in the sauce\n", @response.body
  end

  # :ported:
  def test_render_file_not_using_full_path
    get :render_file_not_using_full_path
    assert_equal "The secret is in the sauce\n", @response.body
  end

  # :ported:
  def test_render_file_not_using_full_path_with_dot_in_path
    get :render_file_not_using_full_path_with_dot_in_path
    assert_equal "The secret is in the sauce\n", @response.body
  end

  # :ported:
  def test_render_file_using_pathname
    get :render_file_using_pathname
    assert_equal "The secret is in the sauce\n", @response.body
  end

  # :ported:
  def test_render_file_with_locals
    get :render_file_with_locals
    assert_equal "The secret is in the sauce\n", @response.body
  end

  # :ported:
  def test_render_file_as_string_with_locals
    get :render_file_as_string_with_locals
    assert_equal "The secret is in the sauce\n", @response.body
  end

  # :assessed:
  def test_render_file_from_template
    get :render_file_from_template
    assert_equal "The secret is in the sauce\n", @response.body
  end

  # :ported:
  def test_render_custom_code
    get :render_custom_code
    assert_response 404
    assert_response :missing
    assert_equal 'hello world', @response.body
  end

  # :ported:
  def test_render_text_with_nil
    get :render_text_with_nil
    assert_response 200
    assert_equal ' ', @response.body
  end

  # :ported:
  def test_render_text_with_false
    get :render_text_with_false
    assert_equal 'false', @response.body
  end

  # :ported:
  def test_render_nothing_with_appendix
    get :render_nothing_with_appendix
    assert_response 200
    assert_equal 'appended', @response.body
  end

  def test_render_text_with_resource
    get :render_text_with_resource
    assert_equal 'name: "David"', @response.body
  end

  # :ported:
  def test_attempt_to_access_object_method
    assert_raise(AbstractController::ActionNotFound, "No action responded to [clone]") { get :clone }
  end

  # :ported:
  def test_private_methods
    assert_raise(AbstractController::ActionNotFound, "No action responded to [determine_layout]") { get :determine_layout }
  end

  # :ported:
  def test_access_to_request_in_view
    get :accessing_request_in_template
    assert_equal "Hello: www.nextangle.com", @response.body
  end

  def test_access_to_logger_in_view
    get :accessing_logger_in_template
    assert_equal "ActiveSupport::Logger", @response.body
  end

  # :ported:
  def test_access_to_action_name_in_view
    get :accessing_action_name_in_template
    assert_equal "accessing_action_name_in_template", @response.body
  end

  # :ported:
  def test_access_to_controller_name_in_view
    get :accessing_controller_name_in_template
    assert_equal "test", @response.body # name is explicitly set in the controller.
  end

  # :ported:
  def test_render_xml
    get :render_xml_hello
    assert_equal "<html>\n  <p>Hello David</p>\n<p>This is grand!</p>\n</html>\n", @response.body
    assert_equal "application/xml", @response.content_type
  end

  # :ported:
  def test_render_xml_as_string_template
    get :render_xml_hello_as_string_template
    assert_equal "<html>\n  <p>Hello David</p>\n<p>This is grand!</p>\n</html>\n", @response.body
    assert_equal "application/xml", @response.content_type
  end

  # :ported:
  def test_render_xml_with_default
    get :greeting
    assert_equal "<p>This is grand!</p>\n", @response.body
  end

  # :move: test in AV
  def test_render_xml_with_partial
    get :builder_partial_test
    assert_equal "<test>\n  <hello/>\n</test>\n", @response.body
  end

  # :ported:
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

  def test_render_to_string_inline
    get :render_to_string_with_inline_and_render
    assert_template "test/hello_world"
  end

  # :ported:
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
    assert_equal "text/html", @response.content_type
  end

  def test_should_implicitly_render_html_template_from_xhr_request
    xhr :get, :render_implicit_html_template_from_xhr_request
    assert_equal "XHR!\nHello HTML!", @response.body
  end

  def test_should_implicitly_render_js_template_without_layout
    get :render_implicit_js_template_without_layout, :format => :js
    assert_no_match %r{<html>}, @response.body
  end

  def test_should_render_formatted_template
    get :formatted_html_erb
    assert_equal 'formatted html erb', @response.body
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

  def test_layout_test_with_different_layout
    get :layout_test_with_different_layout
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_layout_test_with_different_layout_and_string_action
    get :layout_test_with_different_layout_and_string_action
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_layout_test_with_different_layout_and_symbol_action
    get :layout_test_with_different_layout_and_symbol_action
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

  def test_render_to_string_doesnt_break_assigns
    get :render_to_string_with_assigns
    assert_equal "i'm before the render", assigns(:before)
    assert_equal "i'm after the render", assigns(:after)
  end

  def test_bad_render_to_string_still_throws_exception
    assert_raise(ActionView::MissingTemplate) { get :render_to_string_with_exception }
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

  def test_render_with_explicit_unescaped_template
    assert_raise(ActionView::MissingTemplate) { get :render_with_explicit_unescaped_template }
    get :render_with_explicit_escaped_template
    assert_equal "Hello w*rld!", @response.body
  end

  def test_render_with_explicit_string_template
    get :render_with_explicit_string_template
    assert_equal "<html>Hello world!</html>", @response.body
  end

  def test_render_with_filters
    get :render_with_filters
    assert_equal "<test>passed formatted xml erb</test>", @response.body
  end

  # :ported:
  def test_double_render
    assert_raise(AbstractController::DoubleRenderError) { get :double_render }
  end

  def test_double_redirect
    assert_raise(AbstractController::DoubleRenderError) { get :double_redirect }
  end

  def test_render_and_redirect
    assert_raise(AbstractController::DoubleRenderError) { get :render_and_redirect }
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

  # :addressed:
  def test_render_text_with_assigns
    get :render_text_with_assigns
    assert_equal "world", assigns["hello"]
  end

  # :ported:
  def test_template_with_locals
    get :render_with_explicit_template_with_locals
    assert_equal "The secret is area51\n", @response.body
  end

  def test_yield_content_for
    get :yield_content_for
    assert_equal "<title>Putting stuff in the title!</title>\nGreat stuff!\n", @response.body
  end

  def test_overwritting_rendering_relative_file_with_extension
    get :hello_world_from_rxml_using_template
    assert_equal "<html>\n  <p>Hello</p>\n</html>\n", @response.body

    get :hello_world_from_rxml_using_action
    assert_equal "<html>\n  <p>Hello</p>\n</html>\n", @response.body
  end

  def test_head_created
    post :head_created
    assert_blank @response.body
    assert_response :created
  end

  def test_head_created_with_application_json_content_type
    post :head_created_with_application_json_content_type
    assert_blank @response.body
    assert_equal "application/json", @response.content_type
    assert_response :created
  end

  def test_head_with_location_header
    get :head_with_location_header
    assert_blank @response.body
    assert_equal "/foo", @response.headers["Location"]
    assert_response :ok
  end

  def test_head_with_location_object
    with_routing do |set|
      set.draw do
        resources :customers
        get ':controller/:action'
      end

      get :head_with_location_object
      assert_blank @response.body
      assert_equal "http://www.nextangle.com/customers/1", @response.headers["Location"]
      assert_response :ok
    end
  end

  def test_head_with_custom_header
    get :head_with_custom_header
    assert_blank @response.body
    assert_equal "something", @response.headers["X-Custom-Header"]
    assert_response :ok
  end

  def test_head_with_www_authenticate_header
    get :head_with_www_authenticate_header
    assert_blank @response.body
    assert_equal "something", @response.headers["WWW-Authenticate"]
    assert_response :ok
  end

  def test_head_with_symbolic_status
    get :head_with_symbolic_status, :status => "ok"
    assert_equal 200, @response.status
    assert_response :ok

    get :head_with_symbolic_status, :status => "not_found"
    assert_equal 404, @response.status
    assert_response :not_found

    get :head_with_symbolic_status, :status => "no_content"
    assert_equal 204, @response.status
    assert !@response.headers.include?('Content-Length')
    assert_response :no_content

    Rack::Utils::SYMBOL_TO_STATUS_CODE.each do |status, code|
      get :head_with_symbolic_status, :status => status.to_s
      assert_equal code, @response.response_code
      assert_response status
    end
  end

  def test_head_with_integer_status
    Rack::Utils::HTTP_STATUS_CODES.each do |code, message|
      get :head_with_integer_status, :status => code.to_s
      assert_equal message, @response.message
    end
  end

  def test_head_with_string_status
    get :head_with_string_status, :status => "404 Eat Dirt"
    assert_equal 404, @response.response_code
    assert_equal "Not Found", @response.message
    assert_response :not_found
  end

  def test_head_with_status_code_first
    get :head_with_status_code_first
    assert_equal 403, @response.response_code
    assert_equal "Forbidden", @response.message
    assert_equal "something", @response.headers["X-Custom-Header"]
    assert_response :forbidden
  end

  def test_using_layout_around_block
    get :render_using_layout_around_block
    assert_equal "Before (David)\nInside from block\nAfter", @response.body
  end

  def test_using_layout_around_block_in_main_layout_and_within_content_for_layout
    get :render_using_layout_around_block_in_main_layout_and_within_content_for_layout
    assert_equal "Before (Anthony)\nInside from first block in layout\nAfter\nBefore (David)\nInside from block\nAfter\nBefore (Ramm)\nInside from second block in layout\nAfter\n", @response.body
  end

  def test_partial_only
    get :partial_only
    assert_equal "only partial", @response.body
    assert_equal "text/html", @response.content_type
  end

  def test_should_render_html_formatted_partial
    get :partial
    assert_equal "partial html", @response.body
    assert_equal "text/html", @response.content_type
  end

  def test_render_html_formatted_partial_even_with_other_mime_time_in_accept
    @request.accept = "text/javascript, text/html"

    get :partial_html_erb

    assert_equal "partial.html.erb", @response.body.strip
    assert_equal "text/html", @response.content_type
  end

  def test_should_render_html_partial_with_formats
    get :partial_formats_html
    assert_equal "partial html", @response.body
    assert_equal "text/html", @response.content_type
  end

  def test_render_to_string_partial
    get :render_to_string_with_partial
    assert_equal "only partial", assigns(:partial_only)
    assert_equal "Hello: david", assigns(:partial_with_locals)
    assert_equal "text/html", @response.content_type
  end

  def test_render_to_string_with_template_and_html_partial
    get :render_to_string_with_template_and_html_partial
    assert_equal "**only partial**\n", assigns(:text)
    assert_equal "<strong>only partial</strong>\n", assigns(:html)
    assert_equal "<strong>only html partial</strong>\n", @response.body
    assert_equal "text/html", @response.content_type
  end

  def test_render_to_string_and_render_with_different_formats
    get :render_to_string_and_render_with_different_formats
    assert_equal "<strong>only partial</strong>\n", assigns(:html)
    assert_equal "**only partial**\n", @response.body
    assert_equal "text/plain", @response.content_type
  end

  def test_render_template_within_a_template_with_other_format
    get :render_template_within_a_template_with_other_format
    expected = "only html partial<p>This is grand!</p>"
    assert_equal expected, @response.body.strip
    assert_equal "text/html", @response.content_type
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

  def test_nested_partial_with_form_builder
    @controller = Fun::GamesController.new
    get :nested_partial_with_form_builder
    assert_match(/<label/, @response.body)
    assert_template('fun/games/_form')
  end

  def test_namespaced_object_partial
    @controller = Quiz::QuestionsController.new
    get :new
    assert_equal "Namespaced Partial", @response.body
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

  def test_partial_collection_with_as_and_counter
    get :partial_collection_with_as_and_counter
    assert_equal "david0mary1", @response.body
  end

  def test_partial_collection_with_locals
    get :partial_collection_with_locals
    assert_equal "Bonjour: davidBonjour: mary", @response.body
  end

  def test_locals_option_to_assert_template_is_not_supported
    warning_buffer = StringIO.new
    $stderr = warning_buffer

    get :partial_collection_with_locals
    assert_template partial: 'customer_greeting', locals: { greeting: 'Bonjour' }
    assert_equal "the :locals option to #assert_template is only supported in a ActionView::TestCase\n", warning_buffer.string
  ensure
    $stderr = STDERR
  end

  def test_partial_collection_with_spacer
    get :partial_collection_with_spacer
    assert_equal "Hello: davidonly partialHello: mary", @response.body
    assert_template :partial => '_customer'
  end

  def test_partial_collection_with_spacer_which_uses_render
    get :partial_collection_with_spacer_which_uses_render
    assert_equal "Hello: davidpartial html\npartial with partial\nHello: mary", @response.body
    assert_template :partial => '_customer'
  end

  def test_partial_collection_shorthand_with_locals
    get :partial_collection_shorthand_with_locals
    assert_equal "Bonjour: davidBonjour: mary", @response.body
    assert_template :partial => 'customers/_customer', :count => 2
    assert_template :partial => '_completely_fake_and_made_up_template_that_cannot_possibly_be_rendered', :count => 0
  end

  def test_partial_collection_shorthand_with_different_types_of_records
    get :partial_collection_shorthand_with_different_types_of_records
    assert_equal "Bonjour bad customer: mark0Bonjour good customer: craig1Bonjour bad customer: john2Bonjour good customer: zach3Bonjour good customer: brandon4Bonjour bad customer: dan5", @response.body
    assert_template :partial => 'good_customers/_good_customer', :count => 3
    assert_template :partial => 'bad_customers/_bad_customer', :count => 3
  end

  def test_empty_partial_collection
    get :empty_partial_collection
    assert_equal " ", @response.body
    assert_template :partial => false
  end

  def test_partial_with_hash_object
    get :partial_with_hash_object
    assert_equal "Sam\nmaS\n", @response.body
  end

  def test_partial_with_nested_object
    get :partial_with_nested_object
    assert_equal "first", @response.body
  end

  def test_partial_with_nested_object_shorthand
    get :partial_with_nested_object_shorthand
    assert_equal "first", @response.body
  end

  def test_hash_partial_collection
    get :partial_hash_collection
    assert_equal "Pratik\nkitarP\nAmy\nymA\n", @response.body
  end

  def test_partial_hash_collection_with_locals
    get :partial_hash_collection_with_locals
    assert_equal "Hola: PratikHola: Amy", @response.body
  end

  def test_render_missing_partial_template
    assert_raise(ActionView::MissingTemplate) do
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

class ExpiresInRenderTest < ActionController::TestCase
  tests TestController

  def setup
    @request.host = "www.nextangle.com"
  end

  def test_expires_in_header
    get :conditional_hello_with_expires_in
    assert_equal "max-age=60, private", @response.headers["Cache-Control"]
  end

  def test_expires_in_header_with_public
    get :conditional_hello_with_expires_in_with_public
    assert_equal "max-age=60, public", @response.headers["Cache-Control"]
  end

  def test_expires_in_header_with_must_revalidate
    get :conditional_hello_with_expires_in_with_must_revalidate
    assert_equal "max-age=60, private, must-revalidate", @response.headers["Cache-Control"]
  end

  def test_expires_in_header_with_public_and_must_revalidate
    get :conditional_hello_with_expires_in_with_public_and_must_revalidate
    assert_equal "max-age=60, public, must-revalidate", @response.headers["Cache-Control"]
  end

  def test_expires_in_header_with_additional_headers
    get :conditional_hello_with_expires_in_with_public_with_more_keys
    assert_equal "max-age=60, public, s-maxage=18000", @response.headers["Cache-Control"]
  end

  def test_expires_in_old_syntax
    get :conditional_hello_with_expires_in_with_public_with_more_keys_old_syntax
    assert_equal "max-age=60, public, s-maxage=18000", @response.headers["Cache-Control"]
  end

  def test_expires_now
    get :conditional_hello_with_expires_now
    assert_equal "no-cache", @response.headers["Cache-Control"]
  end

  def test_expires_now_with_cache_control_headers
    get :conditional_hello_with_cache_control_headers
    assert_match(/no-cache/, @response.headers["Cache-Control"])
    assert_match(/no-transform/, @response.headers["Cache-Control"])
  end

  def test_date_header_when_expires_in
    time = Time.mktime(2011,10,30)
    Time.stubs(:now).returns(time)
    get :conditional_hello_with_expires_in
    assert_equal Time.now.httpdate, @response.headers["Date"]
  end
end

class LastModifiedRenderTest < ActionController::TestCase
  tests TestController

  def setup
    super
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
    assert_equal 304, @response.status.to_i
    assert_blank @response.body
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
    assert_equal 200, @response.status.to_i
    assert_present @response.body
    assert_equal @last_modified, @response.headers['Last-Modified']
  end


  def test_responds_with_last_modified_with_record
    get :conditional_hello_with_record
    assert_equal @last_modified, @response.headers['Last-Modified']
  end

  def test_request_not_modified_with_record
    @request.if_modified_since = @last_modified
    get :conditional_hello_with_record
    assert_equal 304, @response.status.to_i
    assert_blank @response.body
    assert_equal @last_modified, @response.headers['Last-Modified']
  end

  def test_request_not_modified_but_etag_differs_with_record
    @request.if_modified_since = @last_modified
    @request.if_none_match = "234"
    get :conditional_hello_with_record
    assert_response :success
  end

  def test_request_modified_with_record
    @request.if_modified_since = 'Thu, 16 Jul 2008 00:00:00 GMT'
    get :conditional_hello_with_record
    assert_equal 200, @response.status.to_i
    assert_present @response.body
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

class EtagRenderTest < ActionController::TestCase
  tests TestControllerWithExtraEtags

  def setup
    super
    @request.host = "www.nextangle.com"
  end

  def test_multiple_etags
    @request.if_none_match = %("#{Digest::MD5.hexdigest(ActiveSupport::Cache.expand_cache_key([ "123", 'ab', :cde, [:f] ]))}")
    get :fresh
    assert_response :not_modified

    @request.if_none_match = %("nomatch")
    get :fresh
    assert_response :success
  end
end


class MetalRenderTest < ActionController::TestCase
  tests MetalTestController

  def test_access_to_logger_in_view
    get :accessing_logger_in_template
    assert_equal "NilClass", @response.body
  end
end
