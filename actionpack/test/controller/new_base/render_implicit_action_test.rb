# frozen_string_literal: true

require "abstract_unit"

module RenderImplicitAction
  class SimpleController < ::ApplicationController
    self.view_paths = [ActionView::FixtureResolver.new(
      "render_implicit_action/simple/hello_world.html.erb"     => "Hello world!",
      "render_implicit_action/simple/hyphen-ated.html.erb"     => "Hello hyphen-ated!",
      "render_implicit_action/simple/not_implemented.html.erb" => "Not Implemented"
    ), ActionView::FileSystemResolver.new(File.expand_path("../../controller", __dir__))]

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

    test "render an action called not_implemented" do
      get "/render_implicit_action/simple/not_implemented"

      assert_body   "Not Implemented"
      assert_status 200
    end

    test "render does not traverse the file system" do
      assert_raises(AbstractController::ActionNotFound) do
        action_name = %w(.. .. fixtures shared).join(File::SEPARATOR)
        SimpleController.action(action_name).call(Rack::MockRequest.env_for("/"))
      end
    end

    test "available_action? returns true for implicit actions" do
      assert SimpleController.new.available_action?(:hello_world)
      assert SimpleController.new.available_action?(:"hyphen-ated")
      assert SimpleController.new.available_action?(:not_implemented)
    end

    test "available_action? does not allow File::SEPARATOR on the name" do
      action_name = %w(evil .. .. path).join(File::SEPARATOR)
      assert_equal false, SimpleController.new.available_action?(action_name.to_sym)

      action_name = %w(evil path).join(File::SEPARATOR)
      assert_equal false, SimpleController.new.available_action?(action_name.to_sym)
    end
  end
end
