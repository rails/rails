# frozen_string_literal: true

require "abstract_unit"

module RenderStreaming
  class BasicController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new(
      "render_streaming/basic/hello_world.html.erb" => "Hello world",
      "render_streaming/basic/boom.html.erb" => "<%= raise 'Ruby was here!' %>",
      "layouts/application.html.erb" => "<%= yield %>, I'm here!",
      "layouts/boom.html.erb" => "<body class=\"<%= nil.invalid! %>\"<%= yield %></body>"
    )]

    layout "application"

    def hello_world
      render stream: true
    end

    def layout_exception
      render action: "hello_world", stream: true, layout: "boom"
    end

    def template_exception
      render action: "boom", stream: true
    end

    def skip
      render action: "hello_world", stream: false
    end

    def explicit
      render action: "hello_world", stream: true
    end

    def no_layout
      render action: "hello_world", stream: true, layout: false
    end

    def explicit_cache
      headers["Cache-Control"] = "private"
      render action: "hello_world", stream: true
    end
  end

  class StreamingTest < Rack::TestCase
    test "rendering with streaming enabled at the class level" do
      get "/render_streaming/basic/hello_world"
      assert_body "Hello world, I'm here!"
      assert_streaming!
    end

    test "rendering with streaming given to render" do
      get "/render_streaming/basic/explicit"
      assert_body "Hello world, I'm here!"
      assert_streaming!
    end

    test "rendering with streaming do not override explicit cache control given to render" do
      get "/render_streaming/basic/explicit_cache"
      assert_body "Hello world, I'm here!"
      assert_streaming! "private"
    end

    test "rendering with streaming no layout" do
      get "/render_streaming/basic/no_layout"
      assert_body "Hello world"
      assert_streaming!
    end

    test "skip rendering with streaming at render level" do
      get "/render_streaming/basic/skip"
      assert_body "Hello world, I'm here!"
    end

    test "rendering with layout exception" do
      get "/render_streaming/basic/layout_exception"
      assert_body "<body class=\"\"><script>window.location = \"/500.html\"</script></html>"
      assert_streaming!
    end

    test "rendering with template exception" do
      get "/render_streaming/basic/template_exception"
      assert_body "\"><script>window.location = \"/500.html\"</script></html>"
      assert_streaming!
    end

    test "rendering with template exception logs the exception" do
      io = StringIO.new
      _old, ActionView::Base.logger = ActionView::Base.logger, ActiveSupport::Logger.new(io)

      begin
        get "/render_streaming/basic/template_exception"
        io.rewind
        assert_match "Ruby was here!", io.read
      ensure
        ActionView::Base.logger = _old
      end
    end

    def assert_streaming!(cache = "no-cache")
      assert_status 200
      assert_equal cache, headers["cache-control"]
    end
  end
end
