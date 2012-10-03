require 'fileutils'
require 'abstract_unit'
require 'active_record_unit'

CACHE_DIR = 'test_cache'
# Don't change '/../temp/' cavalierly or you might hose something you don't want hosed
FILE_STORE_PATH = File.join(File.dirname(__FILE__), '/../temp/', CACHE_DIR)

class FragmentCachingMetalTestController < ActionController::Metal
  abstract!

  include ActionController::Caching

  def some_action; end
end

class FragmentCachingMetalTest < ActionController::TestCase
  def setup
    super
    @store = ActiveSupport::Cache::MemoryStore.new
    @controller = FragmentCachingMetalTestController.new
    @controller.perform_caching = true
    @controller.cache_store = @store
    @params = { controller: 'posts', action: 'index'}
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @controller.params = @params
    @controller.request = @request
    @controller.response = @response
  end

  def test_fragment_cache_key
    assert_equal 'views/what a key', @controller.fragment_cache_key('what a key')
  end
end

class CachingController < ActionController::Base
  abstract!

  self.cache_store = :file_store, FILE_STORE_PATH
end

class FragmentCachingTestController < CachingController
  def some_action; end;
end

class FragmentCachingTest < ActionController::TestCase
  def setup
    super
    @store = ActiveSupport::Cache::MemoryStore.new
    @controller = FragmentCachingTestController.new
    @controller.perform_caching = true
    @controller.cache_store = @store
    @params = {:controller => 'posts', :action => 'index'}
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @controller.params = @params
    @controller.request = @request
    @controller.response = @response
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
    @controller.perform_caching = false
    @store.write('views/name', 'value')
    assert_nil @controller.read_fragment('name')
  end

  def test_fragment_exist_with_caching_enabled
    @store.write('views/name', 'value')
    assert @controller.fragment_exist?('name')
    assert !@controller.fragment_exist?('other_name')
  end

  def test_fragment_exist_with_caching_disabled
    @controller.perform_caching = false
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
    @controller.perform_caching = false
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

    @controller.expire_fragment(/name/)

    assert_nil @store.read('views/name')
    assert_nil @store.read('views/another_name')
    assert_equal 'will not expire ;-)', @store.read('views/primalgrasp')
  end

  def test_fragment_for
    @store.write('views/expensive', 'fragment content')
    fragment_computed = false

    view_context = @controller.view_context

    buffer = 'generated till now -> '.html_safe
    buffer << view_context.send(:fragment_for, 'expensive') { fragment_computed = true }

    assert !fragment_computed
    assert_equal 'generated till now -> fragment content', buffer
  end

  def test_html_safety
    assert_nil @store.read('views/name')
    content = 'value'.html_safe
    assert_equal content, @controller.write_fragment('name', content)

    cached = @store.read('views/name')
    assert_equal content, cached
    assert_equal String, cached.class

    html_safe = @controller.read_fragment('name')
    assert_equal content, html_safe
    assert html_safe.html_safe?
  end
end

class FunctionalCachingController < CachingController
  def fragment_cached
  end

  def html_fragment_cached_with_partial
    respond_to do |format|
      format.html
    end
  end

  def formatted_fragment_cached
    respond_to do |format|
      format.html
      format.xml
    end
  end
end

class FunctionalFragmentCachingTest < ActionController::TestCase
  def setup
    super
    @store = ActiveSupport::Cache::MemoryStore.new
    @controller = FunctionalCachingController.new
    @controller.perform_caching = true
    @controller.cache_store = @store
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
  end

  def test_fragment_caching
    get :fragment_cached
    assert_response :success
    expected_body = <<-CACHED
Hello
This bit's fragment cached
Ciao
CACHED
    assert_equal expected_body, @response.body

    assert_equal "This bit's fragment cached",
      @store.read("views/test.host/functional_caching/fragment_cached/#{template_digest("functional_caching/fragment_cached", "html")}")
  end

  def test_fragment_caching_in_partials
    get :html_fragment_cached_with_partial
    assert_response :success
    assert_match(/Old fragment caching in a partial/, @response.body)

    assert_match("Old fragment caching in a partial",
      @store.read("views/test.host/functional_caching/html_fragment_cached_with_partial/#{template_digest("functional_caching/_partial", "html")}"))
  end

  def test_render_inline_before_fragment_caching
    get :inline_fragment_cached
    assert_response :success
    assert_match(/Some inline content/, @response.body)
    assert_match(/Some cached content/, @response.body)
    assert_match("Some cached content",
      @store.read("views/test.host/functional_caching/inline_fragment_cached/#{template_digest("functional_caching/inline_fragment_cached", "html")}"))
  end

  def test_html_formatted_fragment_caching
    get :formatted_fragment_cached, :format => "html"
    assert_response :success
    expected_body = "<body>\n<p>ERB</p>\n</body>\n"

    assert_equal expected_body, @response.body

    assert_equal "<p>ERB</p>",
      @store.read("views/test.host/functional_caching/formatted_fragment_cached/#{template_digest("functional_caching/formatted_fragment_cached", "html")}")
  end

  def test_xml_formatted_fragment_caching
    get :formatted_fragment_cached, :format => "xml"
    assert_response :success
    expected_body = "<body>\n  <p>Builder</p>\n</body>\n"

    assert_equal expected_body, @response.body

    assert_equal "  <p>Builder</p>\n",
      @store.read("views/test.host/functional_caching/formatted_fragment_cached/#{template_digest("functional_caching/formatted_fragment_cached", "xml")}")
  end

  private
    def template_digest(name, format)
      ActionView::Digestor.digest(name, format, @controller.lookup_context)
    end
end

class CacheHelperOutputBufferTest < ActionController::TestCase

  class MockController
    def read_fragment(name, options)
      return false
    end

    def write_fragment(name, fragment, options)
      fragment
    end
  end

  def setup
    super
  end

  def test_output_buffer
    output_buffer = ActionView::OutputBuffer.new
    controller = MockController.new
    cache_helper = Object.new
    cache_helper.extend(ActionView::Helpers::CacheHelper)
    cache_helper.expects(:controller).returns(controller).at_least(0)
    cache_helper.expects(:output_buffer).returns(output_buffer).at_least(0)
    # if the output_buffer is changed, the new one should be html_safe and of the same type
    cache_helper.expects(:output_buffer=).with(responds_with(:html_safe?, true)).with(instance_of(output_buffer.class)).at_least(0)

    assert_nothing_raised do
      cache_helper.send :fragment_for, 'Test fragment name', 'Test fragment', &Proc.new{ nil }
    end
  end

  def test_safe_buffer
    output_buffer = ActiveSupport::SafeBuffer.new
    controller = MockController.new
    cache_helper = Object.new
    cache_helper.extend(ActionView::Helpers::CacheHelper)
    cache_helper.expects(:controller).returns(controller).at_least(0)
    cache_helper.expects(:output_buffer).returns(output_buffer).at_least(0)
    # if the output_buffer is changed, the new one should be html_safe and of the same type
    cache_helper.expects(:output_buffer=).with(responds_with(:html_safe?, true)).with(instance_of(output_buffer.class)).at_least(0)

    assert_nothing_raised do
      cache_helper.send :fragment_for, 'Test fragment name', 'Test fragment', &Proc.new{ nil }
    end
  end
end

class DeprecatedPageCacheExtensionTest < ActiveSupport::TestCase
  def test_page_cache_extension_binds_default_static_extension
    deprecation_behavior = ActiveSupport::Deprecation.behavior
    ActiveSupport::Deprecation.behavior = :silence
    old_extension = ActionController::Base.default_static_extension

    ActionController::Base.page_cache_extension = '.rss'

    assert_equal '.rss', ActionController::Base.default_static_extension
  ensure
    ActiveSupport::Deprecation.behavior = deprecation_behavior
    ActionController::Base.default_static_extension = old_extension
  end
end
