# frozen_string_literal: true

require "abstract_unit"
require "zlib"

class StaticTest < ActiveSupport::TestCase
  DummyApp = lambda { |env|
    [200, { Rack::CONTENT_TYPE => "text/plain" }, ["Hello, World!"]]
  }

  def public_path
    "public"
  end

  def setup
    silence_warnings do
      @default_internal_encoding = Encoding.default_internal
      @default_external_encoding = Encoding.default_external
    end
    @root = "#{FIXTURE_LOAD_PATH}/#{public_path}"
    @app = build_app(DummyApp, @root, headers: { "cache-control" => "public, max-age=60" })
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
    assert_equal "Hello, World!", get((+"/doorkeeper%E3E4").force_encoding("ASCII-8BIT")).body
  end

  def test_handles_urls_with_ascii_8bit_on_win_31j
    silence_warnings do
      Encoding.default_internal = "Windows-31J"
      Encoding.default_external = "Windows-31J"
    end
    assert_equal "Hello, World!", get((+"/doorkeeper%E3E4").force_encoding("ASCII-8BIT")).body
  end

  def test_handles_urls_with_null_byte
    assert_equal "Hello, World!", get("/doorkeeper%00").body
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
    assert_html "means hello in Japanese\n", get("/foo/%E3%81%93%E3%82%93%E3%81%AB%E3%81%A1%E3%81%AF.html")
  end

  def test_served_gzipped_static_file_with_non_english_filename
    response = get("/foo/%E3%81%95%E3%82%88%E3%81%86%E3%81%AA%E3%82%89.html", "HTTP_ACCEPT_ENCODING" => "gzip")

    assert_gzip  "/foo/さようなら.html", response
    assert_equal "text/html",          response.headers["content-type"]
    assert_equal "accept-encoding",    response.headers["vary"]
    assert_equal "gzip",               response.headers["content-encoding"]
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

  JAVASCRIPT_MIME_TYPE = Rack::Mime::MIME_TYPES[".js"]

  def test_serves_gzip_files_when_header_set
    file_name = "/gzip/application-a71b3024f80aea3181c09774ca17e712.js"
    response  = get(file_name, "HTTP_ACCEPT_ENCODING" => "gzip")
    assert_gzip  file_name, response
    assert_equal JAVASCRIPT_MIME_TYPE, response.headers["content-type"]
    assert_equal "accept-encoding", response.headers["vary"]
    assert_equal "gzip", response.headers["content-encoding"]

    response = get(file_name, "HTTP_ACCEPT_ENCODING" => "Gzip")
    assert_gzip file_name, response

    response = get(file_name, "HTTP_ACCEPT_ENCODING" => "GZIP")
    assert_gzip file_name, response

    response = get(file_name, "HTTP_ACCEPT_ENCODING" => "compress;q=0.5, gzip;q=1.0")
    assert_gzip file_name, response

    response = get(file_name, "HTTP_ACCEPT_ENCODING" => "")
    assert_not_equal "gzip", response.headers["content-encoding"]
  end

  def test_serves_gzip_files_when_svg
    file_name = "/gzip/logo-bcb6d75d927347158af5.svg"
    response  = get(file_name, "HTTP_ACCEPT_ENCODING" => "gzip")
    assert_gzip  file_name, response
    assert_equal "image/svg+xml", response.headers["Content-Type"]
    assert_equal "accept-encoding",        response.headers["Vary"]
    assert_equal "gzip",                   response.headers["Content-Encoding"]
  end

  def test_set_vary_when_origin_compressed_but_client_cant_accept
    file_name = "/gzip/application-a71b3024f80aea3181c09774ca17e712.js"
    response  = get(file_name, "HTTP_ACCEPT_ENCODING" => "None")
    assert_equal "accept-encoding", response.headers["vary"]
  end

  def test_serves_brotli_files_when_header_set
    file_name = "/gzip/application-a71b3024f80aea3181c09774ca17e712.js"
    response  = get(file_name, "HTTP_ACCEPT_ENCODING" => "br")
    assert_equal JAVASCRIPT_MIME_TYPE, response.headers["content-type"]
    assert_equal "accept-encoding", response.headers["vary"]
    assert_equal "br", response.headers["content-encoding"]

    response = get(file_name, "HTTP_ACCEPT_ENCODING" => "gzip")
    assert_not_equal "br", response.headers["content-encoding"]
  end

  def test_serves_brotli_files_before_gzip_files
    file_name = "/gzip/application-a71b3024f80aea3181c09774ca17e712.js"
    response  = get(file_name, "HTTP_ACCEPT_ENCODING" => "gzip, deflate, sdch, br")
    assert_equal JAVASCRIPT_MIME_TYPE, response.headers["content-type"]
    assert_equal "accept-encoding", response.headers["vary"]
    assert_equal "br", response.headers["content-encoding"]
  end

  def test_does_not_modify_path_info
    file_name = "/gzip/application-a71b3024f80aea3181c09774ca17e712.js"
    env = Rack::MockRequest.env_for(file_name, { "PATH_INFO" => file_name, "HTTP_ACCEPT_ENCODING" => "gzip", "REQUEST_METHOD" => "POST" })
    @app.call(env)
    assert_equal file_name, env["PATH_INFO"]
  end

  def test_only_set_one_content_type
    file_name = "/gzip/foo.zoo"
    gzip_env = Rack::MockRequest.env_for(file_name, { "PATH_INFO" => file_name, "HTTP_ACCEPT_ENCODING" => "gzip", "REQUEST_METHOD" => "GET" })
    response = @app.call(gzip_env)

    env = Rack::MockRequest.env_for(file_name, { "PATH_INFO" => file_name, "REQUEST_METHOD" => "GET" })
    default_response = @app.call(env)

    assert_equal 1, response[1].slice("Content-Type", "content-type").size
    assert_equal 1, default_response[1].slice("Content-Type", "content-type").size
  end

  def test_serves_gzip_with_proper_content_type_fallback
    file_name = "/gzip/foo.zoo"
    response  = get(file_name, "HTTP_ACCEPT_ENCODING" => "gzip")
    assert_gzip file_name, response

    default_response = get(file_name) # no gzip
    assert_equal default_response.headers["content-type"], response.headers["content-type"]
  end

  def test_serves_gzip_files_with_not_modified
    file_name = "/gzip/application-a71b3024f80aea3181c09774ca17e712.js"
    last_modified = File.mtime(File.join(@root, "#{file_name}.gz"))
    response = get(file_name, "HTTP_ACCEPT_ENCODING" => "gzip", "HTTP_IF_MODIFIED_SINCE" => last_modified.httpdate)
    assert_equal 304, response.status
    assert_nil response.headers["content-type"]
    assert_nil response.headers["content-encoding"]
    assert_nil response.headers["vary"]
  end

  def test_serves_files_with_headers
    headers = {
      "access-control-allow-origin" => "http://rubyonrails.org",
      "cache-control"               => "public, max-age=60",
      "x-custom-header"             => "I'm a teapot"
    }

    @app = build_app(DummyApp, @root, headers: headers)

    response = get("/foo/bar.html")

    assert_equal "http://rubyonrails.org", response.headers["access-control-allow-origin"]
    assert_equal "public, max-age=60",     response.headers["cache-control"]
    assert_equal "I'm a teapot",           response.headers["x-custom-header"]
  end

  def test_ignores_unknown_http_methods
    response = Rack::MockRequest.new(@app).request("BAD_METHOD", "/foo/bar.html")
    assert_equal 200, response.status
  end

  def test_custom_handler_called_when_file_is_outside_root
    filename = "shared.html.erb"
    assert File.exist?(File.join(@root, "..", filename))
    env = Rack::MockRequest.env_for("", {
      "REQUEST_METHOD" => "GET",
      "REQUEST_PATH" => "/..%2F#{filename}",
      "PATH_INFO" => "/..%2F#{filename}",
      "REQUEST_URI" => "/..%2F#{filename}",
    })

    dummy_response = DummyApp.call(nil)
    app_response = @app.call(env)

    assert_equal dummy_response[0], app_response[0]
    assert_equal dummy_response[1], app_response[1]
    assert_equal dummy_response[2].to_a, app_response[2].enum_for.to_a
  end

  def test_non_default_static_index
    @app = build_app(DummyApp, @root, index: "other-index")
    assert_html "/other-index.html", get("/other-index.html")
    assert_html "/other-index.html", get("/other-index")
    assert_html "/other-index.html", get("/")
    assert_html "/other-index.html", get("")
    assert_html "/foo/other-index.html", get("/foo/other-index.html")
    assert_html "/foo/other-index.html", get("/foo/other-index")
    assert_html "/foo/other-index.html", get("/foo/")
    assert_html "/foo/other-index.html", get("/foo")
  end

  # Windows doesn't allow \ / : * ? " < > | in filenames
  unless Gem.win_platform?
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
    def build_app(app, path, index: "index", headers: {})
      Rack::Lint.new(
        ActionDispatch::Static.new(
          Rack::Lint.new(app), path, index: index, headers: headers,
        ),
      )
    end

    def assert_gzip(file_name, response)
      expected = File.read("#{FIXTURE_LOAD_PATH}/#{public_path}" + file_name)
      actual   = ActiveSupport::Gzip.decompress(response.body)
      assert_equal expected, actual
    end

    def assert_html(body, response)
      assert_equal body, response.body
      assert_equal "text/html", response.headers["content-type"]
      assert_nil response.headers["vary"]
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

class StaticEncodingTest < StaticTest
  def public_path
    "公共"
  end
end
