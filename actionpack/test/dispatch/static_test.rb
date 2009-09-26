require 'abstract_unit'

class StaticTest < ActiveSupport::TestCase
  DummyApp = lambda { |env|
    [200, {"Content-Type" => "text/plain"}, ["Hello, World!"]]
  }
  App = ActionDispatch::Static.new(DummyApp, "#{FIXTURE_LOAD_PATH}/public")

  test "serves dynamic content" do
    assert_equal "Hello, World!", get("/nofile")
  end

  test "serves static index at root" do
    assert_equal "/index.html", get("/index.html")
    assert_equal "/index.html", get("/index")
    assert_equal "/index.html", get("/")
  end

  test "serves static file in directory" do
    assert_equal "/foo/bar.html", get("/foo/bar.html")
    assert_equal "/foo/bar.html", get("/foo/bar/")
    assert_equal "/foo/bar.html", get("/foo/bar")
  end

  test "serves static index file in directory" do
    assert_equal "/foo/index.html", get("/foo/index.html")
    assert_equal "/foo/index.html", get("/foo/")
    assert_equal "/foo/index.html", get("/foo")
  end

  private
    def get(path)
      Rack::MockRequest.new(App).request("GET", path).body
    end
end
