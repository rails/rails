require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module HappyPath
  
  class RenderActionController < ActionController::Base2
    
    def render_action_hello_world
      render :action => "hello_world"
    end
    
    def render_action_hello_world_as_string
      render "hello_world"
    end
    
    def render_action_hello_world_as_string_with_options
      render "hello_world", :status => 404
    end
    
    def render_action_hello_world_as_symbol
      render :hello_world
    end

    def render_action_hello_world_with_symbol
      render :action => :hello_world
    end
    
  end
  
  class TestRenderAction < SimpleRouteCase
    
    describe "Rendering an action using :action => <String>"
    
    get "/happy_path/render_action/render_action_hello_world"
    assert_body   "Hello world!"
    assert_status 200
    
  end
  
  class TestRenderActionWithString < SimpleRouteCase
    
    describe "Render an action using 'hello_world'"
    
    get "/happy_path/render_action/render_action_hello_world_as_string"
    assert_body   "Hello world!"
    assert_status 200
    
  end
  
  class TestRenderActionWithStringAndOptions < SimpleRouteCase
    
    describe "Render an action using 'hello_world'"
    
    get "/happy_path/render_action/render_action_hello_world_as_string_with_options"
    assert_body   "Hello world!"
    assert_status 404
    
  end
  
  class TestRenderActionAsSymbol < SimpleRouteCase
    describe "Render an action using :hello_world"
    
    get "/happy_path/render_action/render_action_hello_world_as_symbol"
    assert_body   "Hello world!"
    assert_status 200
  end
  
  class TestRenderActionWithSymbol < SimpleRouteCase
    describe "Render an action using :action => :hello_world"
    
    get "/happy_path/render_action/render_action_hello_world_with_symbol"
    assert_body   "Hello world!"
    assert_status 200
  end

end