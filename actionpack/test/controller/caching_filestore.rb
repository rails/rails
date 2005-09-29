require 'fileutils'
require File.dirname(__FILE__) + '/../abstract_unit'

class TestLogDevice < Logger::LogDevice
  attr :last_message, true
  
  def initialize
    @last_message=String.new
  end
  
  def write(message)
    @last_message << message
  end

  def clear
    @last_message = String.new
  end
end

#setup our really sophisticated logger
TestLog = TestLogDevice.new
RAILS_DEFAULT_LOGGER = Logger.new(TestLog)
ActionController::Base.logger = RAILS_DEFAULT_LOGGER

def use_store
  #generate a random key to ensure the cache is always in a different location
  RANDOM_KEY = rand(99999999).to_s
  FILE_STORE_PATH = File.dirname(__FILE__) + '/../temp/' + RANDOM_KEY
  ActionController::Base.perform_caching = true
  ActionController::Base.fragment_cache_store = :file_store, FILE_STORE_PATH
end

class TestController < ActionController::Base
  caches_action :render_to_cache, :index
 
  def render_to_cache
    render_text "Render Cached"
  end
  alias :index :render_to_cache
end

class FileStoreTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = TestController.new
    @request.host = "hostname.com"
  end
  
  def teardown
    FileUtils.rm_rf(FILE_STORE_PATH)
  end

  def test_render_cached
    assert_fragment_cached { get :render_to_cache }
    assert_fragment_hit { get :render_to_cache }
  end


  private
    def assert_fragment_cached
      yield
      assert(TestLog.last_message.include?("Cached fragment:"), "--ERROR-- FileStore write failed ----")
      assert(!TestLog.last_message.include?("Couldn't create cache directory:"), "--ERROR-- FileStore create directory failed ----")
      TestLog.clear
    end
    
    def assert_fragment_hit
      yield
      assert(TestLog.last_message.include?("Fragment read:"), "--ERROR-- Fragment not found in FileStore ----")
      assert(!TestLog.last_message.include?("Cached fragment:"), "--ERROR-- Did cache ----")
      TestLog.clear
    end
end