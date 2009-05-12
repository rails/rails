require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

# Tests the controller dispatching happy path
module Dispatching
  class SimpleController < ActionController::Base
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
  
  class TestSimpleDispatch < SimpleRouteCase
    
    get "/dispatching/simple/index"
        
    test "sets the body" do
      assert_body "success"
    end
    
    test "sets the status code" do
      assert_status 200
    end
    
    test "sets the content type" do
      assert_content_type "text/html; charset=utf-8"
    end
    
    test "sets the content length" do
      assert_header "Content-Length", "7"
    end
        
  end
  
  # :api: plugin
  class TestDirectResponseMod < SimpleRouteCase
    get "/dispatching/simple/modify_response_body"
        
    test "sets the body" do
      assert_body "success"
    end
    
    test "setting the body manually sets the content length" do
      assert_header "Content-Length", "7"
    end
  end
  
  # :api: plugin
  class TestDirectResponseModTwice < SimpleRouteCase
    get "/dispatching/simple/modify_response_body_twice"
    
    test "self.response_body= returns the body being set" do
      assert_body "success!"
    end
    
    test "updating the response body updates the content length" do
      assert_header "Content-Length", "8"
    end
  end
  
  class EmptyController < ActionController::Base ; end
  module Submodule
    class ContainedEmptyController < ActionController::Base ; end
  end

  class ControllerClassTests < Test::Unit::TestCase
    def test_controller_path
      assert_equal 'dispatching/empty', EmptyController.controller_path
      assert_equal EmptyController.controller_path, EmptyController.new.controller_path
      assert_equal 'dispatching/submodule/contained_empty', Submodule::ContainedEmptyController.controller_path
      assert_equal Submodule::ContainedEmptyController.controller_path, Submodule::ContainedEmptyController.new.controller_path
    end
    def test_controller_name
      assert_equal 'empty', EmptyController.controller_name
      assert_equal 'contained_empty', Submodule::ContainedEmptyController.controller_name
    end
  end
end