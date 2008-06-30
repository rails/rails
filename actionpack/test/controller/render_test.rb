require 'abstract_unit'
require 'controller/fake_models'

module Fun
  class GamesController < ActionController::Base
    def hello_world
    end
  end
end


# FIXME: crashes Ruby 1.9
class TestController < ActionController::Base
  layout :determine_layout

  def hello_world
  end

  def render_hello_world
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

  def render_xml_hello
    @name = "David"
    render :template => "test/hello"
  end

  def render_xml_with_custom_content_type
    render :xml => "<blah/>", :content_type => "application/atomsvc+xml"
  end

  def render_line_offset
    begin
      render :inline => '<% raise %>', :locals => {:foo => 'bar'}
    rescue RuntimeError => exc
    end
    line = exc.backtrace.first
    render :text => line
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
    render :action => "hello"
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

  def partial
    render :partial => 'partial'
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

  def default_render
    if @alternate_default_render
      @alternate_default_render.call
    else
      render
    end
  end

  def render_alternate_default
    # For this test, the method "default_render" is overridden:
    @alternate_default_render = lambda {
	render :update do |page|
	  page.replace :foo, :partial => 'partial'
	end
      }
  end

  def rescue_action(e) raise end

  private
    def determine_layout
      case action_name
        when "layout_test";         "layouts/standard"
        when "builder_layout_test"; "layouts/builder"
        when "render_symbol_json";  "layouts/standard"  # to make sure layouts don't interfere
      end
    end
end

TestController.view_paths = [ File.dirname(__FILE__) + "/../fixtures/" ]
Fun::GamesController.view_paths = [ File.dirname(__FILE__) + "/../fixtures/" ]

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

  def test_render
    get :render_hello_world
    assert_template "test/hello_world"
  end

  def test_line_offset
    get :render_line_offset
    line = @response.body
    assert(line =~ %r{:(\d+):})
    assert_equal "1", $1
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

  def test_render_custom_code
    get :render_custom_code
    assert_response 404
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
    assert_equal '', @response.body
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

  def test_render_200_should_set_etag
    get :render_hello_world_from_variable
    assert_equal etag_for("hello david"), @response.headers['ETag']
    assert_equal "private, max-age=0, must-revalidate", @response.headers['Cache-Control']
  end

  def test_render_against_etag_request_should_304_when_match
    @request.headers["HTTP_IF_NONE_MATCH"] = etag_for("hello david")
    get :render_hello_world_from_variable
    assert_equal "304 Not Modified", @response.headers['Status']
    assert @response.body.empty?
  end

  def test_render_against_etag_request_should_200_when_no_match
    @request.headers["HTTP_IF_NONE_MATCH"] = etag_for("hello somewhere else")
    get :render_hello_world_from_variable
    assert_equal "200 OK", @response.headers['Status']
    assert !@response.body.empty?
  end

  def test_render_with_etag
    get :render_hello_world_from_variable
    expected_etag = etag_for('hello david')
    assert_equal expected_etag, @response.headers['ETag']

    @request.headers["HTTP_IF_NONE_MATCH"] = expected_etag
    get :render_hello_world_from_variable
    assert_equal "304 Not Modified", @response.headers['Status']

    @request.headers["HTTP_IF_NONE_MATCH"] = "\"diftag\""
    get :render_hello_world_from_variable
    assert_equal "200 OK", @response.headers['Status']
  end

  def render_with_404_shouldnt_have_etag
    get :render_custom_code
    assert_nil @response.headers['ETag']
  end

  def test_etag_should_not_be_changed_when_already_set
    expected_etag = etag_for("hello somewhere else")
    @response.headers["ETag"] = expected_etag
    get :render_hello_world_from_variable
    assert_equal expected_etag, @response.headers['ETag']
  end

  def test_etag_should_govern_renders_with_layouts_too
    get :builder_layout_test
    assert_equal "<wrapper>\n<html>\n  <p>Hello </p>\n<p>This is grand!</p>\n</html>\n</wrapper>\n", @response.body
    assert_equal etag_for("<wrapper>\n<html>\n  <p>Hello </p>\n<p>This is grand!</p>\n</html>\n</wrapper>\n"), @response.headers['ETag']
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
    @request.env["HTTP_ACCEPT"] = "image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, appliction/x-shockwave-flash, */*"
    get :formatted_xml_erb
    assert_equal '<test>passed formatted html erb</test>', @response.body
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

  def test_should_render_xml_but_keep_custom_content_type
    get :render_xml_with_custom_content_type
    assert_equal "application/atomsvc+xml", @response.content_type
  end

  protected
  
    def etag_for(text)
      %("#{Digest::MD5.hexdigest(text)}")
    end
end
