require 'abstract_unit'
require 'rbconfig'

module StaticTests
  def test_serves_dynamic_content
    assert_equal "Hello, World!", get("/nofile").body
  end

  def test_handles_urls_with_bad_encoding
    assert_equal "Hello, World!", get("/doorkeeper%E3E4").body
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

  def test_serves_static_file_with_exclamation_mark_in_filename
    with_static_file "/foo/foo!bar.html" do |file|
      assert_html file, get("/foo/foo%21bar.html")
      assert_html file, get("/foo/foo!bar.html")
    end
  end

  def test_serves_static_file_with_dollar_sign_in_filename
    with_static_file "/foo/foo$bar.html" do |file|
      assert_html file, get("/foo/foo%24bar.html")
      assert_html file, get("/foo/foo$bar.html")
    end
  end

  def test_serves_static_file_with_ampersand_in_filename
    with_static_file "/foo/foo&bar.html" do |file|
      assert_html file, get("/foo/foo%26bar.html")
      assert_html file, get("/foo/foo&bar.html")
    end
  end

  def test_serves_static_file_with_apostrophe_in_filename
    with_static_file "/foo/foo'bar.html" do |file|
      assert_html file, get("/foo/foo%27bar.html")
      assert_html file, get("/foo/foo'bar.html")
    end
  end

  def test_serves_static_file_with_parentheses_in_filename
    with_static_file "/foo/foo(bar).html" do |file|
      assert_html file, get("/foo/foo%28bar%29.html")
      assert_html file, get("/foo/foo(bar).html")
    end
  end

  def test_serves_static_file_with_plus_sign_in_filename
    with_static_file "/foo/foo+bar.html" do |file|
      assert_html file, get("/foo/foo%2Bbar.html")
      assert_html file, get("/foo/foo+bar.html")
    end
  end

  def test_serves_static_file_with_comma_in_filename
    with_static_file "/foo/foo,bar.html" do |file|
      assert_html file, get("/foo/foo%2Cbar.html")
      assert_html file, get("/foo/foo,bar.html")
    end
  end

  def test_serves_static_file_with_semi_colon_in_filename
    with_static_file "/foo/foo;bar.html" do |file|
      assert_html file, get("/foo/foo%3Bbar.html")
      assert_html file, get("/foo/foo;bar.html")
    end
  end

  def test_serves_static_file_with_at_symbol_in_filename
    with_static_file "/foo/foo@bar.html" do |file|
      assert_html file, get("/foo/foo%40bar.html")
      assert_html file, get("/foo/foo@bar.html")
    end
  end

  # Windows doesn't allow \ / : * ? " < > | in filenames
  unless RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
    def test_serves_static_file_with_colon
      with_static_file "/foo/foo:bar.html" do |file|
        assert_html file, get("/foo/foo%3Abar.html")
        assert_html file, get("/foo/foo:bar.html")
      end
    end

    def test_serves_static_file_with_asterisk
      with_static_file "/foo/foo*bar.html" do |file|
        assert_html file, get("/foo/foo%2Abar.html")
        assert_html file, get("/foo/foo*bar.html")
      end
    end
  end

  private

    def assert_html(body, response)
      assert_equal body, response.body
      assert_equal "text/html", response.headers["Content-Type"]
    end

    def get(path)
      Rack::MockRequest.new(@app).request("GET", path)
    end

    def with_static_file(file)
      path = "#{FIXTURE_LOAD_PATH}/public" + file
      File.open(path, "wb+") { |f| f.write(file) }
      yield file
    ensure
      File.delete(path)
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
