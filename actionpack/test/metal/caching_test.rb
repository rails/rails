require 'abstract_unit'

CACHE_DIR = 'test_cache'
# Don't change '/../temp/' cavalierly or you might hose something you don't want hosed
FILE_STORE_PATH = File.join(File.dirname(__FILE__), '/../temp/', CACHE_DIR)

class CachingController < ActionController::Metal
  abstract!

  include ActionController::Caching

  self.page_cache_directory = FILE_STORE_PATH
  self.cache_store = :file_store, FILE_STORE_PATH
end

class PageCachingTestController < CachingController
  caches_page :ok

  def ok
    self.response_body = "ok"
  end
end

class PageCachingTest < ActionController::TestCase
  tests PageCachingTestController

  def test_should_cache_get_with_ok_status
    get :ok
    assert_response :ok
    assert File.exist?("#{FILE_STORE_PATH}/page_caching_test/ok.html"), "get with ok status should have been cached"
  end
end
