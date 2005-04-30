require 'fileutils'
require File.dirname(__FILE__) + '/../abstract_unit'

#generate the greatest logging class that ever lived
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

#generate a random key to ensure the cache is always in a different location
RANDOM_KEY = rand(99999999).to_s
FILE_STORE_PATH = File.dirname(__FILE__) + '/../temp/' + RANDOM_KEY
ActionController::Base.perform_caching = true
ActionController::Base.fragment_cache_store = ActionController::Caching::Fragments::FileStore.new(FILE_STORE_PATH)

#setup the routing information...not sure if this does anything
ActionController::Routing::Routes.connect "test", :controller => 'test', :action => 'render_to_cache'

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
    @request.host = "hostname.com"
  end

  #To prime the cache with hostname.com/test
  def test_render_to_cache_prime_a
    @request.path_parameters = {:controller => "test"}
    assert_fragment_cached do process_request end
  end

  #To prime the cache with hostname.com/test/render_to_cache
  def test_render_to_cache_prime_b
    @request.path_parameters = {:action => "render_to_cache", :controller => "test"}
    assert_fragment_cached do process_request end
  end

  #To hit the cache with hostname.com/test 
  def test_render_to_cache_zhit_a
    @request.path_parameters = {:controller => "test"}
    assert_fragment_hit do process_request end
  end

  #To hit the cache with hostname.com/test/render_to_cache
  def test_render_to_cache_zhit_b
    @request.path_parameters = {:action => "render_to_cache", :controller => "test"}
    assert_fragment_hit do process_request end
  end

  private
    def process_request
      TestController.process(@request, @response)
    end
    
    def assert_fragment_cached(&proc)
      proc.call
      assert(TestLog.last_message.include?("Cached fragment:"), "--ERROR-- FileStore write failed ----")
      assert(!TestLog.last_message.include?("Couldn't create cache directory:"), "--ERROR-- FileStore create directory failed ----")
      TestLog.clear
    end
    
    def assert_fragment_hit(&proc)
      proc.call
      assert(TestLog.last_message.include?( "Fragment hit:"), "--ERROR-- Fragment not found in FileStore ----")
      TestLog.clear
    end
end