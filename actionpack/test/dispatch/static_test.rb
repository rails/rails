# encoding: utf-8
require 'abstract_unit'
require 'fileutils'
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

  def test_served_static_file_with_non_english_filename
    assert_html "means hello in Japanese\n", get("/foo/#{Rack::Utils.escape("こんにちは.html")}")
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
      path = "#{FIXTURE_LOAD_PATH}/#{public_path}" + file
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

  def setup
    @root = "#{FIXTURE_LOAD_PATH}/public"
    @app = ActionDispatch::Static.new(DummyApp, @root, "public, max-age=60")
  end

  def public_path
    "public"
  end

  include StaticTests

  def test_custom_handler_called_when_file_is_not_readable
    filename = 'unreadable.html.erb'
    target = File.join(@root, filename)
    FileUtils.touch target
    File.chmod 0200, target
    assert File.exist? target
    assert !File.readable?(target)
    path = "/#{filename}"
    env = {
      "REQUEST_METHOD"=>"GET",
      "REQUEST_PATH"=> path,
      "PATH_INFO"=> path,
      "REQUEST_URI"=> path,
      "HTTP_VERSION"=>"HTTP/1.1",
      "SERVER_NAME"=>"localhost",
      "SERVER_PORT"=>"8080",
      "QUERY_STRING"=>""
    }
    assert_equal(DummyApp.call(nil), @app.call(env))
  ensure
    File.unlink target
  end

  def test_custom_handler_called_when_file_is_outside_root_backslash
    filename = 'shared.html.erb'
    assert File.exist?(File.join(@root, '..', filename))
    path = "/%5C..%2F#{filename}"
    env = {
      "REQUEST_METHOD"=>"GET",
      "REQUEST_PATH"=> path,
      "PATH_INFO"=> path,
      "REQUEST_URI"=> path,
      "HTTP_VERSION"=>"HTTP/1.1",
      "SERVER_NAME"=>"localhost",
      "SERVER_PORT"=>"8080",
      "QUERY_STRING"=>""
    }
    assert_equal(DummyApp.call(nil), @app.call(env))
  end

  def test_custom_handler_called_when_file_is_outside_root
    filename = 'shared.html.erb'
    assert File.exist?(File.join(@root, '..', filename))
    env = {
      "REQUEST_METHOD"=>"GET",
      "REQUEST_PATH"=>"/..%2F#{filename}",
      "PATH_INFO"=>"/..%2F#{filename}",
      "REQUEST_URI"=>"/..%2F#{filename}",
      "HTTP_VERSION"=>"HTTP/1.1",
      "SERVER_NAME"=>"localhost",
      "SERVER_PORT"=>"8080",
      "QUERY_STRING"=>""
    }
    assert_equal(DummyApp.call(nil), @app.call(env))
  end
end

class StaticEncodingTest < StaticTest
  def setup
    @root = "#{FIXTURE_LOAD_PATH}/公共"
    @app = ActionDispatch::Static.new(DummyApp, @root, "public, max-age=60")
  end

  def public_path
    "公共"
  end
end
