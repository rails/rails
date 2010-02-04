require 'fileutils'
require 'abstract_unit'
require 'active_record_unit'

CACHE_DIR = 'test_cache'
# Don't change '/../temp/' cavalierly or you might hose something you don't want hosed
FILE_STORE_PATH = File.join(File.dirname(__FILE__), '/../temp/', CACHE_DIR)
ActionController::Base.page_cache_directory = FILE_STORE_PATH
ActionController::Base.cache_store = :file_store, FILE_STORE_PATH

# Force sweeper classes to load
ActionController::Caching::Sweeper
ActionController::Caching::Sweeping

class PageCachingTestController < ActionController::Base
  caches_page :ok, :no_content, :if => Proc.new { |c| !c.request.format.json? }
  caches_page :found, :not_found

  def ok
    head :ok
  end

  def no_content
    head :no_content
  end

  def found
    redirect_to :action => 'ok'
  end

  def not_found
    head :not_found
  end

  def custom_path
    render :text => "Super soaker"
    cache_page("Super soaker", "/index.html")
  end

  def expire_custom_path
    expire_page("/index.html")
    head :ok
  end

  def trailing_slash
    render :text => "Sneak attack"
  end
end

class PageCachingTest < ActionController::TestCase
  def setup
    ActionController::Base.perform_caching = true

    ActionController::Routing::Routes.draw do |map|
      map.main '', :controller => 'posts', :format => nil
      map.formatted_posts 'posts.:format', :controller => 'posts'
      map.resources :posts
      map.connect ':controller/:action/:id'
    end

    @request = ActionController::TestRequest.new
    @request.host = 'hostname.com'

    @response   = ActionController::TestResponse.new
    @controller = PageCachingTestController.new

    @params = {:controller => 'posts', :action => 'index', :only_path => true, :skip_relative_url_root => true}
    @rewriter = ActionController::UrlRewriter.new(@request, @params)

    FileUtils.rm_rf(File.dirname(FILE_STORE_PATH))
    FileUtils.mkdir_p(FILE_STORE_PATH)
  end

  def teardown
    FileUtils.rm_rf(File.dirname(FILE_STORE_PATH))
    ActionController::Routing::Routes.clear!
    ActionController::Base.perform_caching = false
  end

  def test_page_caching_resources_saves_to_correct_path_with_extension_even_if_default_route
    @params[:format] = 'rss'
    assert_equal '/posts.rss', @rewriter.rewrite(@params)
    @params[:format] = nil
    assert_equal '/', @rewriter.rewrite(@params)
  end

  def test_should_cache_get_with_ok_status
    get :ok
    assert_response :ok
    assert_page_cached :ok, "get with ok status should have been cached"
  end

  def test_should_cache_with_custom_path
    get :custom_path
    assert File.exist?("#{FILE_STORE_PATH}/index.html")
  end

  def test_should_expire_cache_with_custom_path
    get :custom_path
    assert File.exist?("#{FILE_STORE_PATH}/index.html")

    get :expire_custom_path
    assert !File.exist?("#{FILE_STORE_PATH}/index.html")
  end

  def test_should_cache_without_trailing_slash_on_url
    @controller.class.cache_page 'cached content', '/page_caching_test/trailing_slash'
    assert File.exist?("#{FILE_STORE_PATH}/page_caching_test/trailing_slash.html")
  end

  def test_should_cache_with_trailing_slash_on_url
    @controller.class.cache_page 'cached content', '/page_caching_test/trailing_slash/'
    assert File.exist?("#{FILE_STORE_PATH}/page_caching_test/trailing_slash.html")
  end

  def test_should_cache_ok_at_custom_path
    @request.stubs(:path).returns("/index.html")
    get :ok
    assert_response :ok
    assert File.exist?("#{FILE_STORE_PATH}/index.html")
  end

  [:ok, :no_content, :found, :not_found].each do |status|
    [:get, :post, :put, :delete].each do |method|
      unless method == :get and status == :ok
        define_method "test_shouldnt_cache_#{method}_with_#{status}_status" do
          send(method, status)
          assert_response status
          assert_page_not_cached status, "#{method} with #{status} status shouldn't have been cached"
        end
      end
    end
  end

  def test_page_caching_conditional_options
    get :ok, :format=>'json'
    assert_page_not_cached :ok
  end

  private
    def assert_page_cached(action, message = "#{action} should have been cached")
      assert page_cached?(action), message
    end

    def assert_page_not_cached(action, message = "#{action} shouldn't have been cached")
      assert !page_cached?(action), message
    end

    def page_cached?(action)
      File.exist? "#{FILE_STORE_PATH}/page_caching_test/#{action}.html"
    end
end

class ActionCachingTestController < ActionController::Base
  caches_action :index, :redirected, :forbidden, :if => Proc.new { |c| !c.request.format.json? }, :expires_in => 1.hour
  caches_action :show, :cache_path => 'http://test.host/custom/show'
  caches_action :edit, :cache_path => Proc.new { |c| c.params[:id] ? "http://test.host/#{c.params[:id]};edit" : "http://test.host/edit" }
  caches_action :with_layout
  caches_action :layout_false, :layout => false
  caches_action :record_not_found, :four_oh_four, :simple_runtime_error

  layout 'talk_from_action.erb'

  def index
    @cache_this = MockTime.now.to_f.to_s
    render :text => @cache_this
  end

  def redirected
    redirect_to :action => 'index'
  end

  def forbidden
    render :text => "Forbidden"
    response.status = "403 Forbidden"
  end

  def with_layout
    @cache_this = MockTime.now.to_f.to_s
    render :text => @cache_this, :layout => true
  end

  def record_not_found
    raise ActiveRecord::RecordNotFound, "oops!"
  end

  def four_oh_four
    render :text => "404'd!", :status => 404
  end

  def simple_runtime_error
    raise "oops!"
  end

  alias_method :show, :index
  alias_method :edit, :index
  alias_method :destroy, :index
  alias_method :layout_false, :with_layout

  def expire
    expire_action :controller => 'action_caching_test', :action => 'index'
    render :nothing => true
  end

  def expire_xml
    expire_action :controller => 'action_caching_test', :action => 'index', :format => 'xml'
    render :nothing => true
  end
end

class MockTime < Time
  # Let Time spicy to assure that Time.now != Time.now
  def to_f
    super+rand
  end
end

class ActionCachingMockController
  attr_accessor :mock_url_for
  attr_accessor :mock_path

  def initialize
    yield self if block_given?
  end

  def url_for(*args)
    @mock_url_for
  end

  def request
    mocked_path = @mock_path
    Object.new.instance_eval(<<-EVAL)
      def path; '#{@mock_path}' end
      def format; 'all' end
      def cache_format; nil end
      self
    EVAL
  end
end

class ActionCacheTest < ActionController::TestCase
  def setup
    reset!
    FileUtils.mkdir_p(FILE_STORE_PATH)
    @path_class = ActionController::Caching::Actions::ActionCachePath
    @mock_controller = ActionCachingMockController.new
  end

  def teardown
    FileUtils.rm_rf(File.dirname(FILE_STORE_PATH))
  end

  def test_simple_action_cache
    get :index
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert fragment_exist?('hostname.com/action_caching_test')
    reset!

    get :index
    assert_equal cached_time, @response.body
  end

  def test_simple_action_not_cached
    get :destroy
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert !fragment_exist?('hostname.com/action_caching_test/destroy')
    reset!

    get :destroy
    assert_not_equal cached_time, @response.body
  end

  def test_action_cache_with_layout
    get :with_layout
    cached_time = content_to_cache
    assert_not_equal cached_time, @response.body
    assert fragment_exist?('hostname.com/action_caching_test/with_layout')
    reset!

    get :with_layout
    assert_not_equal cached_time, @response.body

    assert_equal @response.body, read_fragment('hostname.com/action_caching_test/with_layout')
  end

  def test_action_cache_with_layout_and_layout_cache_false
    get :layout_false
    cached_time = content_to_cache
    assert_not_equal cached_time, @response.body
    assert fragment_exist?('hostname.com/action_caching_test/layout_false')
    reset!

    get :layout_false
    assert_not_equal cached_time, @response.body

    assert_equal cached_time, read_fragment('hostname.com/action_caching_test/layout_false')
  end

  def test_action_cache_conditional_options
    old_use_accept_header = ActionController::Base.use_accept_header
    ActionController::Base.use_accept_header = true
    @request.env['HTTP_ACCEPT'] = 'application/json'
    get :index
    assert !fragment_exist?('hostname.com/action_caching_test')
    ActionController::Base.use_accept_header = old_use_accept_header
  end

  def test_action_cache_with_store_options
    MockTime.expects(:now).returns(12345).once
    @controller.expects(:read_fragment).with('hostname.com/action_caching_test', :expires_in => 1.hour).once
    @controller.expects(:write_fragment).with('hostname.com/action_caching_test', '12345.0', :expires_in => 1.hour).once
    get :index
  end

  def test_action_cache_with_custom_cache_path
    get :show
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert fragment_exist?('test.host/custom/show')
    reset!

    get :show
    assert_equal cached_time, @response.body
  end

  def test_action_cache_with_custom_cache_path_in_block
    get :edit
    assert fragment_exist?('test.host/edit')
    reset!

    get :edit, :id => 1
    assert fragment_exist?('test.host/1;edit')
  end

  def test_cache_expiration
    get :index
    cached_time = content_to_cache
    reset!

    get :index
    assert_equal cached_time, @response.body
    reset!

    get :expire
    reset!

    get :index
    new_cached_time = content_to_cache
    assert_not_equal cached_time, @response.body
    reset!

    get :index
    assert_response :success
    assert_equal new_cached_time, @response.body
  end

  def test_cache_expiration_isnt_affected_by_request_format
    get :index
    cached_time = content_to_cache
    reset!

    @request.set_REQUEST_URI "/action_caching_test/expire.xml"
    get :expire, :format => :xml
    reset!

    get :index
    new_cached_time = content_to_cache
    assert_not_equal cached_time, @response.body
  end

  def test_cache_is_scoped_by_subdomain
    @request.host = 'jamis.hostname.com'
    get :index
    jamis_cache = content_to_cache

    reset!

    @request.host = 'david.hostname.com'
    get :index
    david_cache = content_to_cache
    assert_not_equal jamis_cache, @response.body

    reset!

    @request.host = 'jamis.hostname.com'
    get :index
    assert_equal jamis_cache, @response.body

    reset!

    @request.host = 'david.hostname.com'
    get :index
    assert_equal david_cache, @response.body
  end

  def test_redirect_is_not_cached
    get :redirected
    assert_response :redirect
    reset!

    get :redirected
    assert_response :redirect
  end

  def test_forbidden_is_not_cached
    get :forbidden
    assert_response :forbidden
    reset!

    get :forbidden
    assert_response :forbidden
  end

  def test_xml_version_of_resource_is_treated_as_different_cache
    with_routing do |set|
      set.draw do |map|
        map.connect ':controller/:action.:format'
        map.connect ':controller/:action'
      end

      get :index, :format => 'xml'
      cached_time = content_to_cache
      assert_equal cached_time, @response.body
      assert fragment_exist?('hostname.com/action_caching_test/index.xml')
      reset!

      get :index, :format => 'xml'
      assert_equal cached_time, @response.body
      assert_equal 'application/xml', @response.content_type
      reset!

      get :expire_xml
      reset!

      get :index, :format => 'xml'
      assert_not_equal cached_time, @response.body
    end
  end

  def test_correct_content_type_is_returned_for_cache_hit
    # run it twice to cache it the first time
    get :index, :id => 'content-type.xml'
    get :index, :id => 'content-type.xml'
    assert_equal 'application/xml', @response.content_type
  end

  def test_correct_content_type_is_returned_for_cache_hit_on_action_with_string_key
    # run it twice to cache it the first time
    get :show, :format => 'xml'
    get :show, :format => 'xml'
    assert_equal 'application/xml', @response.content_type
  end

  def test_correct_content_type_is_returned_for_cache_hit_on_action_with_string_key_from_proc
    # run it twice to cache it the first time
    get :edit, :id => 1, :format => 'xml'
    get :edit, :id => 1, :format => 'xml'
    assert_equal 'application/xml', @response.content_type
  end

  def test_empty_path_is_normalized
    @mock_controller.mock_url_for = 'http://example.org/'
    @mock_controller.mock_path    = '/'

    assert_equal 'example.org/index', @path_class.path_for(@mock_controller, {})
  end

  def test_file_extensions
    get :index, :id => 'kitten.jpg'
    get :index, :id => 'kitten.jpg'

    assert_response :success
  end

  def test_record_not_found_returns_404_for_multiple_requests
    get :record_not_found
    assert_response 404
    get :record_not_found
    assert_response 404
  end

  def test_four_oh_four_returns_404_for_multiple_requests
    get :four_oh_four
    assert_response 404
    get :four_oh_four
    assert_response 404
  end

  def test_simple_runtime_error_returns_500_for_multiple_requests
    get :simple_runtime_error
    assert_response 500
    get :simple_runtime_error
    assert_response 500
  end

  private
    def content_to_cache
      assigns(:cache_this)
    end

    def reset!
      @request    = ActionController::TestRequest.new
      @response   = ActionController::TestResponse.new
      @controller = ActionCachingTestController.new
      @request.host = 'hostname.com'
    end

    def fragment_exist?(path)
      @controller.fragment_exist?(path)
    end

    def read_fragment(path)
      @controller.read_fragment(path)
    end
end

class FragmentCachingTestController < ActionController::Base
  def some_action; end;
end

class FragmentCachingTest < ActionController::TestCase
  def setup
    ActionController::Base.perform_caching = true
    @store = ActiveSupport::Cache::MemoryStore.new
    ActionController::Base.cache_store = @store
    @controller = FragmentCachingTestController.new
    @params = {:controller => 'posts', :action => 'index'}
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @controller.params = @params
    @controller.request = @request
    @controller.response = @response
    @controller.send(:initialize_current_url)
    @controller.send(:initialize_template_class, @response)
    @controller.send(:assign_shortcuts, @request, @response)
  end

  def test_fragment_cache_key
    assert_equal 'views/what a key', @controller.fragment_cache_key('what a key')
    assert_equal "views/test.host/fragment_caching_test/some_action",
                  @controller.fragment_cache_key(:controller => 'fragment_caching_test',:action => 'some_action')
  end

  def test_read_fragment_with_caching_enabled
    @store.write('views/name', 'value')
    assert_equal 'value', @controller.read_fragment('name')
  end

  def test_read_fragment_with_caching_disabled
    ActionController::Base.perform_caching = false
    @store.write('views/name', 'value')
    assert_nil @controller.read_fragment('name')
  end

  def test_fragment_exist_with_caching_enabled
    @store.write('views/name', 'value')
    assert @controller.fragment_exist?('name')
    assert !@controller.fragment_exist?('other_name')
  end

  def test_fragment_exist_with_caching_disabled
    ActionController::Base.perform_caching = false
    @store.write('views/name', 'value')
    assert !@controller.fragment_exist?('name')
    assert !@controller.fragment_exist?('other_name')
  end

  def test_write_fragment_with_caching_enabled
    assert_nil @store.read('views/name')
    assert_equal 'value', @controller.write_fragment('name', 'value')
    assert_equal 'value', @store.read('views/name')
  end

  def test_write_fragment_with_caching_disabled
    assert_nil @store.read('views/name')
    ActionController::Base.perform_caching = false
    assert_equal 'value', @controller.write_fragment('name', 'value')
    assert_nil @store.read('views/name')
  end

  def test_expire_fragment_with_simple_key
    @store.write('views/name', 'value')
    @controller.expire_fragment 'name'
    assert_nil @store.read('views/name')
  end

  def test_expire_fragment_with_regexp
    @store.write('views/name', 'value')
    @store.write('views/another_name', 'another_value')
    @store.write('views/primalgrasp', 'will not expire ;-)')

    @controller.expire_fragment /name/

    assert_nil @store.read('views/name')
    assert_nil @store.read('views/another_name')
    assert_equal 'will not expire ;-)', @store.read('views/primalgrasp')
  end

  def test_fragment_for_with_disabled_caching
    ActionController::Base.perform_caching = false

    @store.write('views/expensive', 'fragment content')
    fragment_computed = false

    buffer = 'generated till now -> '.html_safe
    @controller.fragment_for(buffer, 'expensive') { fragment_computed = true }

    assert fragment_computed
    assert_equal 'generated till now -> ', buffer
  end

  def test_fragment_for
    @store.write('views/expensive', 'fragment content')
    fragment_computed = false

    buffer = 'generated till now -> '.html_safe
    @controller.fragment_for(buffer, 'expensive') { fragment_computed = true }

    assert !fragment_computed
    assert_equal 'generated till now -> fragment content', buffer
  end
end

class FunctionalCachingController < ActionController::Base
  def fragment_cached
  end

  def html_fragment_cached_with_partial
    respond_to do |format|
      format.html
    end
  end

  def js_fragment_cached_with_partial
    respond_to do |format|
      format.js
    end
  end

  def formatted_fragment_cached
    respond_to do |format|
      format.html
      format.xml
      format.js
    end
  end

  def rescue_action(e)
    raise e
  end
end

class FunctionalFragmentCachingTest < ActionController::TestCase
  def setup
    ActionController::Base.perform_caching = true
    @store = ActiveSupport::Cache::MemoryStore.new
    ActionController::Base.cache_store = @store
    @controller = FunctionalCachingController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
  end

  def test_fragment_caching
    get :fragment_cached
    assert_response :success
    expected_body = <<-CACHED
Hello
This bit's fragment cached
CACHED
    assert_equal expected_body, @response.body

    assert_equal "This bit's fragment cached", @store.read('views/test.host/functional_caching/fragment_cached')
  end

  def test_fragment_caching_in_partials
    get :html_fragment_cached_with_partial
    assert_response :success
    assert_match /Fragment caching in a partial/, @response.body
    assert_match "Fragment caching in a partial", @store.read('views/test.host/functional_caching/html_fragment_cached_with_partial')
  end

  def test_render_inline_before_fragment_caching
    get :inline_fragment_cached
    assert_response :success
    assert_match /Some inline content/, @response.body
    assert_match /Some cached content/, @response.body
    assert_match "Some cached content", @store.read('views/test.host/functional_caching/inline_fragment_cached')
  end

  def test_fragment_caching_in_rjs_partials
    xhr :get, :js_fragment_cached_with_partial
    assert_response :success
    assert_match /Fragment caching in a partial/, @response.body
    assert_match "Fragment caching in a partial", @store.read('views/test.host/functional_caching/js_fragment_cached_with_partial')
  end

  def test_html_formatted_fragment_caching
    get :formatted_fragment_cached, :format => "html"
    assert_response :success
    expected_body = "<body>\n<p>ERB</p>\n</body>"

    assert_equal expected_body, @response.body

    assert_equal "<p>ERB</p>", @store.read('views/test.host/functional_caching/formatted_fragment_cached')
  end

  def test_xml_formatted_fragment_caching
    get :formatted_fragment_cached, :format => "xml"
    assert_response :success
    expected_body = "<body>\n  <p>Builder</p>\n</body>\n"

    assert_equal expected_body, @response.body

    assert_equal "  <p>Builder</p>\n", @store.read('views/test.host/functional_caching/formatted_fragment_cached')
  end

  def test_js_formatted_fragment_caching
    get :formatted_fragment_cached, :format => "js"
    assert_response :success
    expected_body = %(title = "Hey";\n$("element_1").visualEffect("highlight");\n) +
      %($("element_2").visualEffect("highlight");\nfooter = "Bye";)
    assert_equal expected_body, @response.body

    assert_equal ['$("element_1").visualEffect("highlight");', '$("element_2").visualEffect("highlight");'],
      @store.read('views/test.host/functional_caching/formatted_fragment_cached')
  end
end
