require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module HappyPath
  
  # This has no layout and it works
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
  
  # # ==== Render actions with layouts ====
  
  class RenderActionWithLayoutController < ActionController::Base2
    # Set the view path to an application view structure with layouts
    self.view_paths = [File.join(File.dirname(__FILE__), 'views', 'with_layout')]
    
    def hello_world
      render :action => "hello_world"
    end
  end
  
  class TestRenderActionWithLayout < SimpleRouteCase
    describe %(
      Render hello_world and implicitly use application.html.erb as a layout if 
      no layout is specified and no controller layout is present
    )
      
    get "/happy_path/render_action_with_layout/hello_world"
    assert_body   "OHAI Hello World! KTHXBAI"
    assert_status 200
  end

end