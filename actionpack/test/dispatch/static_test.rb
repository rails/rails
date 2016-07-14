require 'abstract_unit'
require 'zlib'

module StaticTests
  DummyApp = lambda { |env|
    [200, {"Content-Type" => "text/plain"}, ["Hello, World!"]]
  }

  def setup
    silence_warnings do
      @default_internal_encoding = Encoding.default_internal
      @default_external_encoding = Encoding.default_external
    end
  end

  def teardown
    silence_warnings do
      Encoding.default_internal = @default_internal_encoding
      Encoding.default_external = @default_external_encoding
    end
  end

  def test_serves_dynamic_content
    assert_equal "Hello, World!", get("/nofile").body
  end

  def test_handles_urls_with_bad_encoding
    assert_equal "Hello, World!", get("/doorkeeper%E3E4").body
  end

  def test_handles_urls_with_ascii_8bit
    assert_equal "Hello, World!", get("/doorkeeper%E3E4".force_encoding('ASCII-8BIT')).body
  end

  def test_handles_urls_with_ascii_8bit_on_win_31j
    silence_warnings do
      Encoding.default_internal = "Windows-31J"
      Encoding.default_external = "Windows-31J"
    end
    assert_equal "Hello, World!", get("/doorkeeper%E3E4".force_encoding('ASCII-8BIT')).body
  end

  def test_handles_urls_with_null_byte
    assert_equal "Hello, World!", get("/doorkeeper%00").body
  end

  def test_sets_cache_control
    app = assert_deprecated do
      ActionDispatch::Static.new(DummyApp, @root, "public, max-age=60")
    end
    response = Rack::MockRequest.new(app).request("GET", "/index.html")

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
    assert_html "/foo/index.html", get("/foo/index")
    assert_html "/foo/index.html", get("/foo/")
    assert_html "/foo/index.html", get("/foo")
  end

  def test_serves_file_with_same_name_before_index_in_directory
    assert_html "/bar.html", get("/bar")
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

  def test_serves_gzip_files_when_header_set
    file_name = "/gzip/application-a71b3024f80aea3181c09774ca17e712.js"
    response  = get(file_name, 'HTTP_ACCEPT_ENCODING' => 'gzip')
    assert_gzip  file_name, response
    assert_equal 'application/javascript', response.headers['Content-Type']
    assert_equal 'Accept-Encoding',        response.headers["Vary"]
    assert_equal 'gzip',                   response.headers["Content-Encoding"]

    response  = get(file_name, 'HTTP_ACCEPT_ENCODING' => 'Gzip')
    assert_gzip  file_name, response

    response  = get(file_name, 'HTTP_ACCEPT_ENCODING' => 'GZIP')
    assert_gzip  file_name, response

    response  = get(file_name, 'HTTP_ACCEPT_ENCODING' => 'compress;q=0.5, gzip;q=1.0')
    assert_gzip  file_name, response

    response  = get(file_name, 'HTTP_ACCEPT_ENCODING' => '')
    assert_not_equal 'gzip', response.headers["Content-Encoding"]
  end

  def test_does_not_modify_path_info
    file_name = "/gzip/application-a71b3024f80aea3181c09774ca17e712.js"
    env = {'PATH_INFO' => file_name, 'HTTP_ACCEPT_ENCODING' => 'gzip', "REQUEST_METHOD" => 'POST'}
    @app.call(env)
    assert_equal file_name, env['PATH_INFO']
  end

  def test_serves_gzip_with_propper_content_type_fallback
    file_name = "/gzip/foo.zoo"
    response  = get(file_name, 'HTTP_ACCEPT_ENCODING' => 'gzip')
    assert_gzip  file_name, response

    default_response = get(file_name) # no gzip
    assert_equal default_response.headers['Content-Type'], response.headers['Content-Type']
  end

  def test_serves_gzip_files_with_not_modified
    file_name = "/gzip/application-a71b3024f80aea3181c09774ca17e712.js"
    last_modified = File.mtime(File.join(@root, "#{file_name}.gz"))
    response = get(file_name, 'HTTP_ACCEPT_ENCODING' => 'gzip', 'HTTP_IF_MODIFIED_SINCE' => last_modified.httpdate)
    assert_equal 304, response.status
    assert_equal nil, response.headers['Content-Type']
    assert_equal nil, response.headers['Content-Encoding']
    assert_equal nil, response.headers['Vary']
  end

  def test_serves_files_with_headers
    headers = {
      "Access-Control-Allow-Origin" => 'http://rubyonrails.org',
      "Cache-Control"               => 'public, max-age=60',
      "X-Custom-Header"             => "I'm a teapot"
    }

    app      = ActionDispatch::Static.new(DummyApp, @root, headers: headers)
    response = Rack::MockRequest.new(app).request("GET", "/foo/bar.html")

    assert_equal 'http://rubyonrails.org', response.headers["Access-Control-Allow-Origin"]
    assert_equal 'public, max-age=60',     response.headers["Cache-Control"]
    assert_equal "I'm a teapot",           response.headers["X-Custom-Header"]
  end

  def test_ignores_unknown_http_methods
    app = ActionDispatch::Static.new(DummyApp, @root)

    assert_nothing_raised { Rack::MockRequest.new(app).request("BAD_METHOD", "/foo/bar.html") }
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

    def assert_gzip(file_name, response)
      expected = File.read("#{FIXTURE_LOAD_PATH}/#{public_path}" + file_name)
      actual   = Zlib::GzipReader.new(StringIO.new(response.body)).read
      assert_equal expected, actual
    end

    def assert_html(body, response)
      assert_equal body, response.body
      assert_equal "text/html", response.headers["Content-Type"]
      assert_nil response.headers["Vary"]
    end

    def get(path, headers = {})
      Rack::MockRequest.new(@app).request("GET", path, headers)
    end

    def with_static_file(file)
      path = "#{FIXTURE_LOAD_PATH}/#{public_path}" + file
      begin
        File.open(path, "wb+") { |f| f.write(file) }
      rescue Errno::EPROTO
        skip "Couldn't create a file #{path}"
      end

      yield file
    ensure
      File.delete(path) if File.exist? path
    end
end

class StaticTest < ActiveSupport::TestCase
  def setup
    super
    @root = "#{FIXTURE_LOAD_PATH}/public"
    @app = ActionDispatch::Static.new(DummyApp, @root, headers: {'Cache-Control' => "public, max-age=60"})
  end

  def public_path
    "public"
  end

  include StaticTests

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

  def test_non_default_static_index
    @app = ActionDispatch::Static.new(DummyApp, @root, index: "other-index")
    assert_html "/other-index.html", get("/other-index.html")
    assert_html "/other-index.html", get("/other-index")
    assert_html "/other-index.html", get("/")
    assert_html "/other-index.html", get("")
    assert_html "/foo/other-index.html", get("/foo/other-index.html")
    assert_html "/foo/other-index.html", get("/foo/other-index")
    assert_html "/foo/other-index.html", get("/foo/")
    assert_html "/foo/other-index.html", get("/foo")
  end

end

class StaticEncodingTest < StaticTest
  def setup
    super
    @root = "#{FIXTURE_LOAD_PATH}/公共"
    @app = ActionDispatch::Static.new(DummyApp, @root, headers: {'Cache-Control' => "public, max-age=60"})
  end

  def public_path
    "公共"
  end
end
