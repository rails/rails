require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module RenderAction
  # This has no layout and it works
  class BasicController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new(
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

  class RenderActionTest < SimpleRouteCase
    test "rendering an action using :action => <String>" do
      get "/render_action/basic/hello_world"

      assert_body "Hello world!"
      assert_status 200
    end

    test "rendering an action using '<action>'" do
      get "/render_action/basic/hello_world_as_string"

      assert_body "Hello world!"
      assert_status 200
    end

    test "rendering an action using '<action>' and options" do
      get "/render_action/basic/hello_world_as_string_with_options"

      assert_body "Hello world!"
      assert_status 404
    end

    test "rendering an action using :action" do
      get "/render_action/basic/hello_world_as_symbol"

      assert_body "Hello world!"
      assert_status 200
    end

    test "rendering an action using :action => :hello_world" do
      get "/render_action/basic/hello_world_with_symbol"

      assert_body "Hello world!"
      assert_status 200
    end
  end

  class RenderLayoutTest < SimpleRouteCase
    describe "Both <controller_path>.html.erb and application.html.erb are missing"

    test "rendering with layout => true" do
      assert_raise(ArgumentError, /no default layout for RenderAction::BasicController in/) do
        get "/render_action/basic/hello_world_with_layout", {}, "action_dispatch.show_exceptions" => false
      end
    end

    test "rendering with layout => false" do
      get "/render_action/basic/hello_world_with_layout_false"

      assert_body "Hello world!"
      assert_status 200
    end

    test "rendering with layout => :nil" do
      get "/render_action/basic/hello_world_with_layout_nil"

      assert_body "Hello world!"
      assert_status 200
    end

    test "rendering with layout => 'greetings'" do
      assert_raise(ActionView::MissingTemplate) do
        get "/render_action/basic/hello_world_with_custom_layout", {}, "action_dispatch.show_exceptions" => false
      end
    end
  end
end

module RenderActionWithApplicationLayout
  # # ==== Render actions with layouts ====
  class BasicController < ::ApplicationController
    # Set the view path to an application view structure with layouts
    self.view_paths = self.view_paths = [ActionView::FixtureResolver.new(
      "render_action_with_application_layout/basic/hello_world.html.erb" => "Hello World!",
      "render_action_with_application_layout/basic/hello.html.builder"   => "xml.p 'Omg'",
      "layouts/application.html.erb"                                     => "OHAI <%= yield %> KTHXBAI",
      "layouts/greetings.html.erb"                                       => "Greetings <%= yield %> Bai",
      "layouts/builder.html.builder"                                     => "xml.html do\n  xml << yield\nend"
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

    def with_builder_and_layout
      render :action => "hello", :layout => "builder"
    end
  end

  class LayoutTest < SimpleRouteCase
    describe "Only application.html.erb is present and <controller_path>.html.erb is missing"

    test "rendering implicit application.html.erb as layout" do
      get "/render_action_with_application_layout/basic/hello_world"

      assert_body "OHAI Hello World! KTHXBAI"
      assert_status 200
    end

    test "rendering with layout => true" do
      get "/render_action_with_application_layout/basic/hello_world_with_layout"

      assert_body "OHAI Hello World! KTHXBAI"
      assert_status 200
    end

    test "rendering with layout => false" do
      get "/render_action_with_application_layout/basic/hello_world_with_layout_false"

      assert_body "Hello World!"
      assert_status 200
    end

    test "rendering with layout => :nil" do
      get "/render_action_with_application_layout/basic/hello_world_with_layout_nil"

      assert_body "Hello World!"
      assert_status 200
    end

    test "rendering with layout => 'greetings'" do
      get "/render_action_with_application_layout/basic/hello_world_with_custom_layout"

      assert_body "Greetings Hello World! Bai"
      assert_status 200
    end
  end

  class TestLayout < SimpleRouteCase
    testing BasicController

    test "builder works with layouts" do
      get :with_builder_and_layout
      assert_response "<html>\n<p>Omg</p>\n</html>\n"
    end
  end

end

module RenderActionWithControllerLayout
  class BasicController < ActionController::Base
    self.view_paths = self.view_paths = [ActionView::FixtureResolver.new(
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

  class ControllerLayoutTest < SimpleRouteCase
    describe "Only <controller_path>.html.erb is present and application.html.erb is missing"

    test "render hello_world and implicitly use <controller_path>.html.erb as a layout." do
      get "/render_action_with_controller_layout/basic/hello_world"

      assert_body "With Controller Layout! Hello World! KTHXBAI"
      assert_status 200
    end

    test "rendering with layout => true" do
      get "/render_action_with_controller_layout/basic/hello_world_with_layout"

      assert_body "With Controller Layout! Hello World! KTHXBAI"
      assert_status 200
    end

    test "rendering with layout => false" do
      get "/render_action_with_controller_layout/basic/hello_world_with_layout_false"

      assert_body "Hello World!"
      assert_status 200
    end

    test "rendering with layout => :nil" do
      get "/render_action_with_controller_layout/basic/hello_world_with_layout_nil"

      assert_body "Hello World!"
      assert_status 200
    end
  end
end

module RenderActionWithBothLayouts
  class BasicController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new({
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

  class ControllerLayoutTest < SimpleRouteCase
    describe "Both <controller_path>.html.erb and application.html.erb are present"

    test "rendering implicitly use <controller_path>.html.erb over application.html.erb as a layout" do
      get "/render_action_with_both_layouts/basic/hello_world"

      assert_body   "With Controller Layout! Hello World! KTHXBAI"
      assert_status 200
    end

    test "rendering with layout => true" do
      get "/render_action_with_both_layouts/basic/hello_world_with_layout"

      assert_body "With Controller Layout! Hello World! KTHXBAI"
      assert_status 200
    end

    test "rendering with layout => false" do
      get "/render_action_with_both_layouts/basic/hello_world_with_layout_false"

      assert_body "Hello World!"
      assert_status 200
    end

    test "rendering with layout => :nil" do
      get "/render_action_with_both_layouts/basic/hello_world_with_layout_nil"

      assert_body "Hello World!"
      assert_status 200
    end
  end
end