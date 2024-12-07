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
      env = Rack::MockRequest.env_for("/render_streaming/basic/hello_world")
      status, headers, body = app.call(env)
      assert_streaming!(status, headers, body)
      assert_chunks ["Hello world", ", I'm here!"], body

      get "/render_streaming/basic/hello_world"
      assert_body "Hello world, I'm here!"
    end

    test "rendering with streaming given to render" do
      env = Rack::MockRequest.env_for("/render_streaming/basic/explicit")
      status, headers, body = app.call(env)
      assert_streaming!(status, headers, body)
      assert_chunks ["Hello world", ", I'm here!"], body

      get "/render_streaming/basic/explicit"
      assert_body "Hello world, I'm here!"
      assert_cache_control!
    end

    test "rendering with streaming do not override explicit cache control given to render" do
      env = Rack::MockRequest.env_for("/render_streaming/basic/explicit_cache")
      status, headers, body = app.call(env)
      assert_streaming!(status, headers, body)
      assert_chunks ["Hello world", ", I'm here!"], body

      get "/render_streaming/basic/explicit_cache"
      assert_body "Hello world, I'm here!"
      assert_cache_control! "private"
    end

    test "rendering with streaming no layout" do
      env = Rack::MockRequest.env_for("/render_streaming/basic/no_layout")
      status, headers, body = app.call(env)
      assert_streaming!(status, headers, body)
      assert_chunks ["Hello world"], body

      get "/render_streaming/basic/no_layout"
      assert_body "Hello world"
      assert_cache_control!
    end

    test "skip rendering with streaming at render level" do
      env = Rack::MockRequest.env_for("/render_streaming/basic/skip")
      status, _, body = app.call(env)
      assert_equal 200, status
      assert_chunks ["Hello world, I'm here!"], body

      get "/render_streaming/basic/skip"
      assert_body "Hello world, I'm here!"
    end

    test "rendering with layout exception" do
      env = Rack::MockRequest.env_for("/render_streaming/basic/layout_exception")
      status, headers, body = app.call(env)
      assert_streaming!(status, headers, body)
      assert_chunks ["<body class=\"", "\"><script>window.location = \"/500.html\"</script></html>"], body

      get "/render_streaming/basic/layout_exception"
      assert_body "<body class=\"\"><script>window.location = \"/500.html\"</script></html>"
      assert_cache_control!
    end

    test "rendering with template exception" do
      env = Rack::MockRequest.env_for("/render_streaming/basic/template_exception")
      status, headers, body = app.call(env)
      assert_streaming!(status, headers, body)
      assert_chunks ["\"><script>window.location = \"/500.html\"</script></html>"], body

      get "/render_streaming/basic/template_exception"
      assert_body "\"><script>window.location = \"/500.html\"</script></html>"
      assert_cache_control!
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

    def assert_streaming!(status, headers, body)
      assert_equal 200, status

      # It should not have a content length
      assert_nil headers["content-length"]

      # The body should not respond to `#to_ary`
      assert_not_respond_to body, :to_ary
    end

    def assert_cache_control!(value = "no-cache", headers: self.headers)
      assert_equal value, headers["cache-control"]
    end

    def assert_chunks(expected, body)
      index = 0
      body.each do |chunk|
        assert_equal expected[index], chunk
        index += 1
      end

      assert_equal expected.size, index
    end
  end
end
