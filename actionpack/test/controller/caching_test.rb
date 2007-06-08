require 'fileutils'
require File.dirname(__FILE__) + '/../abstract_unit'

CACHE_DIR = 'test_cache'
# Don't change '/../temp/' cavalierly or you might hoze something you don't want hozed
FILE_STORE_PATH = File.join(File.dirname(__FILE__), '/../temp/', CACHE_DIR)
ActionController::Base.page_cache_directory = FILE_STORE_PATH
ActionController::Base.fragment_cache_store = :file_store, FILE_STORE_PATH

class PageCachingTestController < ActionController::Base
  caches_page :ok, :no_content, :found, :not_found

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
end

class PageCachingTest < Test::Unit::TestCase
  def setup
    ActionController::Base.perform_caching = true

    ActionController::Routing::Routes.draw do |map|
      map.main '', :controller => 'posts'
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

  [:ok, :no_content, :found, :not_found].each do |status|
    [:get, :post, :put, :delete].each do |method|
      unless method == :get and status == :ok
        define_method "test_shouldnt_cache_#{method}_with_#{status}_status" do
          @request.env['REQUEST_METHOD'] = method.to_s.upcase
          process status
          assert_response status
          assert_page_not_cached status, "#{method} with #{status} status shouldn't have been cached"
        end
      end
    end
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
  caches_action :index, :redirected, :forbidden
  caches_action :show, :cache_path => 'http://test.host/custom/show'
  caches_action :edit, :cache_path => Proc.new { |c| c.params[:id] ? "http://test.host/#{c.params[:id]};edit" : "http://test.host/edit" }

  def index
    @cache_this = Time.now.to_f.to_s
    render :text => @cache_this
  end

  def redirected
    redirect_to :action => 'index'
  end

  def forbidden
    render :text => "Forbidden"
    headers["Status"] = "403 Forbidden"
  end

  alias_method :show, :index
  alias_method :edit, :index

  def expire
    expire_action :controller => 'action_caching_test', :action => 'index'
    render :nothing => true
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
      self
    EVAL
  end
end

class ActionCacheTest < Test::Unit::TestCase
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
    assert_cache_exists 'hostname.com/action_caching_test'
    reset!

    get :index
    assert_equal cached_time, @response.body
  end
  
  def test_action_cache_with_custom_cache_path
    get :show
    cached_time = content_to_cache
    assert_equal cached_time, @response.body
    assert_cache_exists 'test.host/custom/show'
    reset!

    get :show
    assert_equal cached_time, @response.body
  end

  def test_action_cache_with_custom_cache_path_in_block
    get :edit
    assert_cache_exists 'test.host/edit'
    reset!

    get :edit, :id => 1
    assert_cache_exists 'test.host/1;edit'
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

  def test_cache_is_scoped_by_subdomain
    @request.host = 'jamis.hostname.com'
    get :index
    jamis_cache = content_to_cache

    @request.host = 'david.hostname.com'
    get :index
    david_cache = content_to_cache
    assert_not_equal jamis_cache, @response.body

    @request.host = 'jamis.hostname.com'
    get :index
    assert_equal jamis_cache, @response.body

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
    @mock_controller.mock_url_for = 'http://example.org/posts/'
    @mock_controller.mock_path    = '/posts/index.xml'
    path_object = @path_class.new(@mock_controller, {})
    assert_equal 'xml', path_object.extension
    assert_equal 'example.org/posts/index.xml', path_object.path
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
    
    def assert_cache_exists(path)
      full_path = File.join(FILE_STORE_PATH, path + '.cache')
      assert File.exist?(full_path), "#{full_path.inspect} does not exist."
    end
end
