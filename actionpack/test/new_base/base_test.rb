$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')

require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'action_controller'
require 'action_view/base'

begin
  require 'ruby-debug'
  Debugger.settings[:autoeval] = true
  Debugger.start
rescue LoadError
  # Debugging disabled. `gem install ruby-debug` to enable.
end

require 'action_controller/abstract'
require 'action_controller/new_base'
require 'pp' # require 'pp' early to prevent hidden_methods from not picking up the pretty-print methods until too late

require 'rubygems'
require 'rack/test'

module ActionController
  class Base2 < AbstractBase
    include AbstractController::Callbacks
    include AbstractController::Renderer
    include AbstractController::Helpers
    include AbstractController::Layouts
    include AbstractController::Logger
    
    include ActionController::HideActions
    include ActionController::UrlFor
    include ActionController::Renderer
        
    CORE_METHODS = self.public_instance_methods
  end
end

# Temporary base class
class Rack::TestCase < ActiveSupport::TestCase
  
  include Rack::Test::Methods
  
  setup do
    ActionController::Base.session_options[:key] = "abc"
    ActionController::Base.session_options[:secret] = ("*" * 30)
    ActionController::Routing.use_controllers! %w(happy_path/simple_dispatch)
  end
  
  def self.get(url)
    setup do |test|
      test.get url
    end
  end  
  
  def app
    @app ||= ActionController::Dispatcher.new
  end
  
  def assert_body(body)
    assert_equal [body], last_response.body
  end
  
  def assert_status(code)
    assert_equal code, last_response.status
  end
  
  def assert_content_type(type)
    assert_equal type, last_response.headers["Content-Type"]
  end
  
  def assert_header(name, value)
    assert_equal value, last_response.headers[name]
  end
  
end


# Tests the controller dispatching happy path
module HappyPath
  class SimpleDispatchController < ActionController::Base2
    def index
      render :text => "success"
    end

    def modify_response_body
      self.response_body = "success"
    end
    
    def modify_response_body_twice
      ret = (self.response_body = "success") 
      self.response_body = "#{ret}!"
    end
    
    def modify_response_headers
      
    end
  end
  
  class SimpleRouteCase < Rack::TestCase
    setup do
      ActionController::Routing::Routes.draw do |map|
        map.connect ':controller/:action'
      end
    end
  end
  
  class TestSimpleDispatch < SimpleRouteCase
    
    get "/happy_path/simple_dispatch/index"
        
    test "sets the body" do
      assert_body "success"
    end
    
    test "sets the status code" do
      assert_status 200
    end
    
    test "sets the content type" do
      assert_content_type Mime::HTML
    end
    
    test "sets the content length" do
      assert_header "Content-Length", 7
    end
        
  end
  
  # :api: plugin
  class TestDirectResponseMod < SimpleRouteCase
    get "/happy_path/simple_dispatch/modify_response_body"
        
    test "sets the body" do
      assert_body "success"
    end
    
    test "setting the body manually sets the content length" do
      assert_header "Content-Length", 7
    end
  end
  
  # :api: plugin
  class TestDirectResponseModTwice < SimpleRouteCase
    get "/happy_path/simple_dispatch/modify_response_body_twice"
    
    test "self.response_body= returns the body being set" do
      assert_body "success!"
    end
    
    test "updating the response body updates the content length" do
      assert_header "Content-Length", 8
    end
  end
end


class EmptyController < ActionController::Base2 ; end
module Submodule
  class ContainedEmptyController < ActionController::Base2 ; end
end

class ControllerClassTests < Test::Unit::TestCase
  def test_controller_path
    assert_equal 'empty', EmptyController.controller_path
    assert_equal EmptyController.controller_path, EmptyController.new.controller_path
    assert_equal 'submodule/contained_empty', Submodule::ContainedEmptyController.controller_path
    assert_equal Submodule::ContainedEmptyController.controller_path, Submodule::ContainedEmptyController.new.controller_path
  end
  def test_controller_name
    assert_equal 'empty', EmptyController.controller_name
    assert_equal 'contained_empty', Submodule::ContainedEmptyController.controller_name
 end
end