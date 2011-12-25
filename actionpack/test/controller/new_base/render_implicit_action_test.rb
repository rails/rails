require 'abstract_unit'

module RenderImplicitAction
  class SimpleController < ::ApplicationController
    self.view_paths = [ActionView::FixtureResolver.new(
      "render_implicit_action/simple/hello_world.html.erb"     => "Hello world!",
      "render_implicit_action/simple/hyphen-ated.html.erb"     => "Hello hyphen-ated!",
      "render_implicit_action/simple/not_implemented.html.erb" => "Not Implemented"
    )]

    def hello_world() end
    def unexisted_template() end
  end

  class RenderImplicitActionTest < Rack::TestCase
    test "render a action without any template " do
      get "/render_implicit_action/simple/unexisted_template"
      assert_status 500
    end

    test "render a unexisted format of template" do
      get "/render_implicit_action/simple/hello_world.json"
      assert_status 406
    end

    test "render a simple action with new explicit call to render" do
      get "/render_implicit_action/simple/hello_world"

      assert_body   "Hello world!"
      assert_status 200
    end

    test "render an action with a missing method and has special characters" do
      get "/render_implicit_action/simple/hyphen-ated"

      assert_body   "Hello hyphen-ated!"
      assert_status 200
    end

    test "render an action called not_implemented" do
      get "/render_implicit_action/simple/not_implemented"

      assert_body   "Not Implemented"
      assert_status 200
    end

    test "available_action? returns true for implicit actions" do
      assert SimpleController.new.available_action?(:hello_world)
      assert SimpleController.new.available_action?(:"hyphen-ated")
      assert SimpleController.new.available_action?(:not_implemented)
    end
  end
end
