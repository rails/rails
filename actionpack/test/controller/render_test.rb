require 'abstract_unit'
require 'controller/fake_models'
require 'pathname'

class TestControllerWithExtraEtags < ActionController::Base
  etag { nil  }
  etag { 'ab' }
  etag { :cde }
  etag { [:f] }
  etag { nil  }

  def fresh
    render text: "stale" if stale?(etag: '123')
  end

  def array
    render text: "stale" if stale?(etag: %w(1 2 3))
  end
end

class TestController < ActionController::Base
  protect_from_forgery

  before_action :set_variable_for_layout

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

  def dynamic_render
    render params[:id] # => String, AC:Params
  end

  def dynamic_render_permit
    render params[:id].permit(:file)
  end

  def dynamic_render_with_file
    # This is extremely bad, but should be possible to do.
    file = params[:id] # => String, AC:Params
    render file: file
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
  before_action :handle_last_modified_and_etags, :only=>:conditional_hello_with_bangs

  def handle_last_modified_and_etags
    fresh_when(:last_modified => Time.now.utc.beginning_of_day, :etag => [ :foo, 123 ])
  end

  def heading
    head :ok
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

  def head_created
    head :created
  end

  def head_created_with_application_json_content_type
    head :created, :content_type => "application/json"
  end

  def head_ok_with_image_png_content_type
    head :ok, :content_type => "image/png"
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
  include AbstractController::Rendering
  include ActionView::Rendering
  include ActionController::Rendering

  def accessing_logger_in_template
    render :inline =>  "<%= logger.class %>"
  end
end

class MetalWithoutAVTestController < ActionController::Metal
  include AbstractController::Rendering
  include ActionController::Rendering
  include ActionController::StrongParameters

  def dynamic_params_render
    render params
  end
end

class ExpiresInRenderTest < ActionController::TestCase
  tests TestController

  def setup
    super
    ActionController::Base.view_paths.paths.each(&:clear_cache)
  end

  def test_dynamic_render_with_file
    # This is extremely bad, but should be possible to do.
    assert File.exist?(File.join(File.dirname(__FILE__), '../../test/abstract_unit.rb'))
    response = get :dynamic_render_with_file, { id: '../\\../test/abstract_unit.rb' }
    assert_equal File.read(File.join(File.dirname(__FILE__), '../../test/abstract_unit.rb')),
      response.body
  end

  def test_dynamic_render_with_absolute_path
    file = Tempfile.new('name')
    file.write "secrets!"
    file.flush
    assert_raises ActionView::MissingTemplate do
      get :dynamic_render, { id: file.path }
    end
  ensure
    file.close
    file.unlink
  end

  def test_dynamic_render
    assert File.exist?(File.join(File.dirname(__FILE__), '../../test/abstract_unit.rb'))
    assert_raises ActionView::MissingTemplate do
      get :dynamic_render, { id: '../\\../test/abstract_unit.rb' }
    end
  end

  def test_permitted_dynamic_render_file_hash
    assert File.exist?(File.join(File.dirname(__FILE__), '../../test/abstract_unit.rb'))
    response = get :dynamic_render_permit, { id: { file: '../\\../test/abstract_unit.rb' } }
    assert_equal File.read(File.join(File.dirname(__FILE__), '../../test/abstract_unit.rb')),
      response.body
  end

  def test_dynamic_render_file_hash
    e = assert_raises ArgumentError do
      get :dynamic_render, { id: { file: '../\\../test/abstract_unit.rb' } }
    end
    assert_equal "render parameters are not permitted", e.message
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
    assert @response.body.blank?
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
    assert @response.body.present?
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
    assert @response.body.blank?
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
    assert @response.body.present?
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
  end

  def test_multiple_etags
    @request.if_none_match = etag(["123", 'ab', :cde, [:f]])
    get :fresh
    assert_response :not_modified

    @request.if_none_match = %("nomatch")
    get :fresh
    assert_response :success
  end

  def test_array
    @request.if_none_match = etag([%w(1 2 3), 'ab', :cde, [:f]])
    get :array
    assert_response :not_modified

    @request.if_none_match = %("nomatch")
    get :array
    assert_response :success
  end

  def etag(record)
    Digest::MD5.hexdigest(ActiveSupport::Cache.expand_cache_key(record)).inspect
  end
end

class MetalRenderTest < ActionController::TestCase
  tests MetalTestController

  def test_access_to_logger_in_view
    get :accessing_logger_in_template
    assert_equal "NilClass", @response.body
  end
end

class MetalRenderWithoutAVTest < ActionController::TestCase
  tests MetalWithoutAVTestController

  def test_dynamic_params_render
    e = assert_raises ArgumentError do
      get :dynamic_params_render, { inline: '<%= RUBY_VERSION %>' }
    end
    assert_equal "render parameters are not permitted", e.message
  end
end

class HeadRenderTest < ActionController::TestCase
  tests TestController

  def setup
    @request.host = "www.nextangle.com"
  end

  def test_head_created
    post :head_created
    assert @response.body.blank?
    assert_response :created
  end

  def test_head_created_with_application_json_content_type
    post :head_created_with_application_json_content_type
    assert @response.body.blank?
    assert_equal "application/json", @response.header["Content-Type"]
    assert_response :created
  end

  def test_head_ok_with_image_png_content_type
    post :head_ok_with_image_png_content_type
    assert @response.body.blank?
    assert_equal "image/png", @response.header["Content-Type"]
    assert_response :ok
  end

  def test_head_with_location_header
    get :head_with_location_header
    assert @response.body.blank?
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
      assert @response.body.blank?
      assert_equal "http://www.nextangle.com/customers/1", @response.headers["Location"]
      assert_response :ok
    end
  end

  def test_head_with_custom_header
    get :head_with_custom_header
    assert @response.body.blank?
    assert_equal "something", @response.headers["X-Custom-Header"]
    assert_response :ok
  end

  def test_head_with_www_authenticate_header
    get :head_with_www_authenticate_header
    assert @response.body.blank?
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
end
