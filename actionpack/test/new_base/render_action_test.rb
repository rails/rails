require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module RenderAction
  
  # This has no layout and it works
  class BasicController < ActionController::Base2
    
    self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(
      "render_action/basic/hello_world.html.erb" => "Hello world!"
    )]
    
    def hello_world
      render :action => "hello_world"
    end
    
    def hello_world_as_string
      render "hello_world"
    end
    
    def hello_world_as_string_with_options
      render "hello_world", :status => 404
    end
    
    def hello_world_as_symbol
      render :hello_world
    end

    def hello_world_with_symbol
      render :action => :hello_world
    end
    
    def hello_world_with_layout
      render :action => "hello_world", :layout => true
    end
    
    def hello_world_with_layout_false
      render :action => "hello_world", :layout => false
    end
    
    def hello_world_with_layout_nil
      render :action => "hello_world", :layout => nil
    end
    
    def hello_world_with_custom_layout
      render :action => "hello_world", :layout => "greetings"
    end
    
  end
  
  class TestBasic < SimpleRouteCase
    describe "Rendering an action using :action => <String>"
    
    get "/render_action/basic/hello_world"
    assert_body   "Hello world!"
    assert_status 200
  end
  
  class TestWithString < SimpleRouteCase
    describe "Render an action using 'hello_world'"
    
    get "/render_action/basic/hello_world_as_string"
    assert_body   "Hello world!"
    assert_status 200
  end
  
  class TestWithStringAndOptions < SimpleRouteCase
    describe "Render an action using 'hello_world'"
    
    get "/render_action/basic/hello_world_as_string_with_options"
    assert_body   "Hello world!"
    assert_status 404
  end
  
  class TestAsSymbol < SimpleRouteCase
    describe "Render an action using :hello_world"
    
    get "/render_action/basic/hello_world_as_symbol"
    assert_body   "Hello world!"
    assert_status 200
  end
  
  class TestWithSymbol < SimpleRouteCase
    describe "Render an action using :action => :hello_world"
    
    get "/render_action/basic/hello_world_with_symbol"
    assert_body   "Hello world!"
    assert_status 200
  end
  
  class TestLayoutTrue < SimpleRouteCase
    describe "rendering a normal template with full path with layout => true"
    
    test "raises an exception when requesting a layout and none exist" do
      assert_raise(ArgumentError, /no default layout for RenderAction::BasicController in/) do 
        get "/render_action/basic/hello_world_with_layout"
      end
    end
  end
  
  class TestLayoutFalse < SimpleRouteCase
    describe "rendering a normal template with full path with layout => false"
    
    get "/render_action/basic/hello_world_with_layout_false"
    assert_body   "Hello world!"
    assert_status 200
  end
  
  class TestLayoutNil < SimpleRouteCase
    describe "rendering a normal template with full path with layout => :nil"
    
    get "/render_action/basic/hello_world_with_layout_nil"
    assert_body   "Hello world!"
    assert_status 200
  end
  
  class TestCustomLayout < SimpleRouteCase
    describe "rendering a normal template with full path with layout => 'greetings'"
    
    test "raises an exception when requesting a layout that does not exist" do
      assert_raise(ActionView::MissingTemplate) { get "/render_action/basic/hello_world_with_custom_layout" }
    end
  end
  
end

module RenderActionWithApplicationLayout
  
  # # ==== Render actions with layouts ====

  class BasicController < ::ApplicationController
    # Set the view path to an application view structure with layouts
    self.view_paths = self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(
      "render_action_with_application_layout/basic/hello_world.html.erb" => "Hello World!",
      "layouts/application.html.erb"                                     => "OHAI <%= yield %> KTHXBAI",
      "layouts/greetings.html.erb"                                       => "Greetings <%= yield %> Bai"
    )]
    
    def hello_world
      render :action => "hello_world"
    end
    
    def hello_world_with_layout
      render :action => "hello_world", :layout => true
    end
    
    def hello_world_with_layout_false
      render :action => "hello_world", :layout => false
    end
    
    def hello_world_with_layout_nil
      render :action => "hello_world", :layout => nil
    end
    
    def hello_world_with_custom_layout
      render :action => "hello_world", :layout => "greetings"
    end
  end
  
  class TestDefaultLayout < SimpleRouteCase
    describe %(
      Render hello_world and implicitly use application.html.erb as a layout if 
      no layout is specified and no controller layout is present
    )
      
    get "/render_action_with_application_layout/basic/hello_world"
    assert_body   "OHAI Hello World! KTHXBAI"
    assert_status 200
  end
  
  class TestLayoutTrue < SimpleRouteCase
    describe "rendering a normal template with full path with layout => true"
    
    get "/render_action_with_application_layout/basic/hello_world_with_layout"
    assert_body   "OHAI Hello World! KTHXBAI"
    assert_status 200
  end
  
  class TestLayoutFalse < SimpleRouteCase
    describe "rendering a normal template with full path with layout => false"
    
    get "/render_action_with_application_layout/basic/hello_world_with_layout_false"
    assert_body   "Hello World!"
    assert_status 200
  end
  
  class TestLayoutNil < SimpleRouteCase
    describe "rendering a normal template with full path with layout => :nil"
    
    get "/render_action_with_application_layout/basic/hello_world_with_layout_nil"
    assert_body   "Hello World!"
    assert_status 200
  end
  
  class TestCustomLayout < SimpleRouteCase
    describe "rendering a normal template with full path with layout => 'greetings'"
    
    get "/render_action_with_application_layout/basic/hello_world_with_custom_layout"
    assert_body   "Greetings Hello World! Bai"
    assert_status 200
  end
  
end

module RenderActionWithControllerLayout
  
  class BasicController < ActionController::Base2
    self.view_paths = self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(
      "render_action_with_controller_layout/basic/hello_world.html.erb" => "Hello World!",
      "layouts/render_action_with_controller_layout/basic.html.erb"     => "With Controller Layout! <%= yield %> KTHXBAI"
    )]
    
    def hello_world
      render :action => "hello_world"
    end
    
    def hello_world_with_layout
      render :action => "hello_world", :layout => true
    end
    
    def hello_world_with_layout_false
      render :action => "hello_world", :layout => false
    end
    
    def hello_world_with_layout_nil
      render :action => "hello_world", :layout => nil
    end
    
    def hello_world_with_custom_layout
      render :action => "hello_world", :layout => "greetings"
    end
  end
  
  class TestControllerLayout < SimpleRouteCase
    describe "Render hello_world and implicitly use <controller_path>.html.erb as a layout."

    get "/render_action_with_controller_layout/basic/hello_world"
    assert_body   "With Controller Layout! Hello World! KTHXBAI"
    assert_status 200
  end
  
  class TestLayoutTrue < SimpleRouteCase
    describe "rendering a normal template with full path with layout => true"
    
    get "/render_action_with_controller_layout/basic/hello_world_with_layout"
    assert_body   "With Controller Layout! Hello World! KTHXBAI"
    assert_status 200
  end
  
  class TestLayoutFalse < SimpleRouteCase
    describe "rendering a normal template with full path with layout => false"
    
    get "/render_action_with_controller_layout/basic/hello_world_with_layout_false"
    assert_body   "Hello World!"
    assert_status 200
  end
  
  class TestLayoutNil < SimpleRouteCase
    describe "rendering a normal template with full path with layout => :nil"
    
    get "/render_action_with_controller_layout/basic/hello_world_with_layout_nil"
    assert_body   "Hello World!"
    assert_status 200
  end
  
end

module RenderActionWithBothLayouts
  
  class BasicController < ActionController::Base2
    self.view_paths = [ActionView::FixtureTemplate::FixturePath.new({
      "render_action_with_both_layouts/basic/hello_world.html.erb" => "Hello World!",
      "layouts/application.html.erb"                                => "OHAI <%= yield %> KTHXBAI",
      "layouts/render_action_with_both_layouts/basic.html.erb"      => "With Controller Layout! <%= yield %> KTHXBAI"
    })]
    
    def hello_world
      render :action => "hello_world"
    end
    
    def hello_world_with_layout
      render :action => "hello_world", :layout => true
    end
    
    def hello_world_with_layout_false
      render :action => "hello_world", :layout => false
    end
    
    def hello_world_with_layout_nil
      render :action => "hello_world", :layout => nil
    end
  end
  
  class TestControllerLayoutFirst < SimpleRouteCase
    describe "Render hello_world and implicitly use <controller_path>.html.erb over application.html.erb as a layout"

    get "/render_action_with_both_layouts/basic/hello_world"
    assert_body   "With Controller Layout! Hello World! KTHXBAI"
    assert_status 200
  end
  
  class TestLayoutTrue < SimpleRouteCase
    describe "rendering a normal template with full path with layout => true"
    
    get "/render_action_with_both_layouts/basic/hello_world_with_layout"
    assert_body   "With Controller Layout! Hello World! KTHXBAI"
    assert_status 200
  end
  
  class TestLayoutFalse < SimpleRouteCase
    describe "rendering a normal template with full path with layout => false"
    
    get "/render_action_with_both_layouts/basic/hello_world_with_layout_false"
    assert_body   "Hello World!"
    assert_status 200
  end
  
  class TestLayoutNil < SimpleRouteCase
    describe "rendering a normal template with full path with layout => :nil"
    
    get "/render_action_with_both_layouts/basic/hello_world_with_layout_nil"
    assert_body   "Hello World!"
    assert_status 200
  end
  
end