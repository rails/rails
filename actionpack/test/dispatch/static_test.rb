# encoding: utf-8
require 'abstract_unit'

module StaticTests
  def test_serves_dynamic_content
    assert_equal "Hello, World!", get("/nofile").body
  end

  def test_sets_cache_control
    response = get("/index.html")
    assert_html "/index.html", response
    assert_equal "public, max-age=60", response.headers["Cache-Control"]
  end

  def test_serves_static_index_at_root
    assert_html "/index.html", get("/index.html")
    assert_html "/index.html", get("/index")
    assert_html "/index.html", get("/")
    assert_html "/index.html", get("")
  end

  def test_serves_static_file_in_directory
    assert_html "/foo/bar.html", get("/foo/bar.html")
    assert_html "/foo/bar.html", get("/foo/bar/")
    assert_html "/foo/bar.html", get("/foo/bar")
  end

  def test_serves_static_index_file_in_directory
    assert_html "/foo/index.html", get("/foo/index.html")
    assert_html "/foo/index.html", get("/foo/")
    assert_html "/foo/index.html", get("/foo")
  end

  def test_served_static_file_with_non_english_filename
    assert_html "means hello in Japanese\n", get("/foo/#{Rack::Utils.escape("こんにちは.html")}")
  end

  private

    def assert_html(body, response)
      assert_equal body, response.body
      assert_equal "text/html", response.headers["Content-Type"]
    end

    def get(path)
      Rack::MockRequest.new(@app).request("GET", path)
    end
end

class StaticTest < ActiveSupport::TestCase
  DummyApp = lambda { |env|
    [200, {"Content-Type" => "text/plain"}, ["Hello, World!"]]
  }
  App = ActionDispatch::Static.new(DummyApp, "#{FIXTURE_LOAD_PATH}/public", "public, max-age=60")

  def setup
    @app = App
  end

  include StaticTests
end
