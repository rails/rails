require 'abstract_unit'

require 'action_controller'
require 'rails/rack'

class RackStaticTest < ActiveSupport::TestCase
  def setup
    FileUtils.cp_r "#{RAILS_ROOT}/fixtures/public", "#{RAILS_ROOT}/public"
  end

  def teardown
    FileUtils.rm_rf "#{RAILS_ROOT}/public"
  end

  DummyApp = lambda { |env|
    [200, {"Content-Type" => "text/plain"}, ["Hello, World!"]]
  }
  App = Rails::Rack::Static.new(DummyApp)

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
