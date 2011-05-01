require 'abstract_unit'

module RenderContext
  class BasicController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new(
      "render_context/basic/hello_world.html.erb" => "<%= @value %> from <%= self.__controller_method__ %>",
      "layouts/basic.html.erb" => "?<%= yield %>?"
    )]

    # Include ViewContext
    include ActionView::Context

    # And initialize the required variables
    before_filter do
      @output_buffer = nil
      @virtual_path  = nil
      @view_flow     = ActionView::OutputFlow.new
    end

    def hello_world
      @value = "Hello"
      render :action => "hello_world", :layout => false
    end

    def with_layout
      @value = "Hello"
      render :action => "hello_world", :layout => "basic"
    end

    protected

    def view_context
      self
    end

    def __controller_method__
      "controller context!"
    end
  end

  class RenderContextTest < Rack::TestCase
    test "rendering using the controller as context" do
      get "/render_context/basic/hello_world"
      assert_body "Hello from controller context!"
      assert_status 200
    end

    test "rendering using the controller as context with layout" do
      get "/render_context/basic/with_layout"
      assert_body "?Hello from controller context!?"
      assert_status 200
    end
  end
end
