require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module Render
  class BlankRenderController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new(
      "render/blank_render/index.html.erb"                  => "Hello world!",
      "render/blank_render/access_request.html.erb"         => "The request: <%= request.method.to_s.upcase %>",
      "render/blank_render/access_action_name.html.erb"     => "Action Name: <%= action_name %>",
      "render/blank_render/access_controller_name.html.erb" => "Controller Name: <%= controller_name %>"
    )]

    def index
      render
    end

    def access_request
      render :action => "access_request"
    end

    def render_action_name
      render :action => "access_action_name"
    end

    private

    def secretz
      render :text => "FAIL WHALE!"
    end
  end

  class DoubleRenderController < ActionController::Base
    def index
      render :text => "hello"
      render :text => "world"
    end
  end

  class RenderTest < SimpleRouteCase
    test "render with blank" do
      get "/render/blank_render"

      assert_body "Hello world!"
      assert_status 200
    end

    test "rendering more than once raises an exception" do
      assert_raises(AbstractController::DoubleRenderError) do
        get "/render/double_render", {}, "action_dispatch.show_exceptions" => false
      end
    end
  end

  class TestOnlyRenderPublicActions < SimpleRouteCase
    describe "Only public methods on actual controllers are callable actions"

    test "raises an exception when a method of Object is called" do
      assert_raises(AbstractController::ActionNotFound) do
        get "/render/blank_render/clone", {}, "action_dispatch.show_exceptions" => false
      end
    end

    test "raises an exception when a private method is called" do
      assert_raises(AbstractController::ActionNotFound) do
        get "/render/blank_render/secretz", {}, "action_dispatch.show_exceptions" => false
      end
    end
  end
  
  class TestVariousObjectsAvailableInView < SimpleRouteCase
    test "The request object is accessible in the view" do
      get "/render/blank_render/access_request"
      assert_body "The request: GET"
    end

    test "The action_name is accessible in the view" do
      get "/render/blank_render/render_action_name"
      assert_body "Action Name: render_action_name"
    end

    test "The controller_name is accessible in the view" do
      get "/render/blank_render/access_controller_name"
      assert_body "Controller Name: blank_render"
    end
  end
end