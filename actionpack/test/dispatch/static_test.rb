require 'abstract_unit'

module StaticTests
  def test_serves_dynamic_content
    assert_equal "Hello, World!", get("/nofile")
  end

  def test_serves_static_index_at_root
    assert_equal "/index.html", get("/index.html")
    assert_equal "/index.html", get("/index")
    assert_equal "/index.html", get("/")
  end

  def test_serves_static_file_in_directory
    assert_equal "/foo/bar.html", get("/foo/bar.html")
    assert_equal "/foo/bar.html", get("/foo/bar/")
    assert_equal "/foo/bar.html", get("/foo/bar")
  end

  def test_serves_static_index_file_in_directory
    assert_equal "/foo/index.html", get("/foo/index.html")
    assert_equal "/foo/index.html", get("/foo/")
    assert_equal "/foo/index.html", get("/foo")
  end

  private
    def get(path)
      Rack::MockRequest.new(@app).request("GET", path).body
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
    assert_equal "/blog/index.html", get("/blog/index.html")
    assert_equal "/blog/index.html", get("/blog/index")
    assert_equal "/blog/index.html", get("/blog/")

    assert_equal "/blog/blog.html", get("/blog/blog/")
    assert_equal "/blog/blog.html", get("/blog/blog.html")
    assert_equal "/blog/blog.html", get("/blog/blog")

    assert_equal "/blog/subdir/index.html", get("/blog/subdir/index.html")
    assert_equal "/blog/subdir/index.html", get("/blog/subdir/")
    assert_equal "/blog/subdir/index.html", get("/blog/subdir")
  end
end
