require 'abstract_unit'

module RenderImplicitAction
  class SimpleController < ::ApplicationController
    self.view_paths = [ActionView::FixtureResolver.new(
      "render_implicit_action/simple/hello_world.html.erb" => "Hello world!",
      "render_implicit_action/simple/hyphen-ated.html.erb" => "Hello hyphen-ated!"
    )]

    def hello_world() end
  end

  class RenderImplicitActionTest < Rack::TestCase
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
  end
end
