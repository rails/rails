require 'abstract_unit'

module RenderStreaming
  class BasicController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new(
      "render_streaming/basic/hello_world.html.erb" => "Hello world",
      "layouts/application.html.erb" => "<%= yield %>, I'm here!"
    )]

    layout "application"
    stream :only => :hello_world

    def hello_world
    end

    def explicit
      render :action => "hello_world", :stream => true
    end

    def no_layout
      render :action => "hello_world", :stream => true, :layout => false
    end

    def explicit_cache
      headers["Cache-Control"] = "private"
      render :action => "hello_world", :stream => true
    end
  end

  class StreamingTest < Rack::TestCase
    test "rendering with streaming enabled at the class level" do
      get "/render_streaming/basic/hello_world"
      assert_body "b\r\nHello world\r\nb\r\n, I'm here!\r\n0\r\n\r\n"
      assert_streaming!
    end

    test "rendering with streaming given to render" do
      get "/render_streaming/basic/explicit"
      assert_body "b\r\nHello world\r\nb\r\n, I'm here!\r\n0\r\n\r\n"
      assert_streaming!
    end

    test "rendering with streaming do not override explicit cache control given to render" do
      get "/render_streaming/basic/explicit_cache"
      assert_body "b\r\nHello world\r\nb\r\n, I'm here!\r\n0\r\n\r\n"
      assert_streaming! "private"
    end

    test "rendering with streaming no layout" do
      get "/render_streaming/basic/no_layout"
      assert_body "b\r\nHello world\r\n0\r\n\r\n"
      assert_streaming!
    end

    def assert_streaming!(cache="no-cache")
      assert_status 200
      assert_equal nil, headers["Content-Length"]
      assert_equal "chunked", headers["Transfer-Encoding"]
      assert_equal cache, headers["Cache-Control"]
    end
  end if defined?(Fiber)
end
