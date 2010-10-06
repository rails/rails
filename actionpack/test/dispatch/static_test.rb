require 'abstract_unit'

module StaticTests
  def test_serves_dynamic_content
    assert_equal "Hello, World!", get("/nofile").body
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
  App = ActionDispatch::Static.new(DummyApp, "#{FIXTURE_LOAD_PATH}/public")

  def setup
    @app = App
  end

  include StaticTests
end

class MultipleDirectorisStaticTest < ActiveSupport::TestCase
  DummyApp = lambda { |env|
    [200, {"Content-Type" => "text/plain"}, ["Hello, World!"]]
  }
  App = ActionDispatch::Static.new(DummyApp,
            { "/"     => "#{FIXTURE_LOAD_PATH}/public",
              "/blog" => "#{FIXTURE_LOAD_PATH}/blog_public",
              "/foo"  => "#{FIXTURE_LOAD_PATH}/non_existing_dir"
            })

  def setup
    @app = App
  end

  include StaticTests

  test "serves files from other mounted directories" do
    assert_html "/blog/index.html", get("/blog/index.html")
    assert_html "/blog/index.html", get("/blog/index")
    assert_html "/blog/index.html", get("/blog/")

    assert_html "/blog/blog.html", get("/blog/blog/")
    assert_html "/blog/blog.html", get("/blog/blog.html")
    assert_html "/blog/blog.html", get("/blog/blog")

    assert_html "/blog/subdir/index.html", get("/blog/subdir/index.html")
    assert_html "/blog/subdir/index.html", get("/blog/subdir/")
    assert_html "/blog/subdir/index.html", get("/blog/subdir")
  end
end
