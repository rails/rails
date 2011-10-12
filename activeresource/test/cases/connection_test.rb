require 'abstract_unit'

class ConnectionTest < Test::Unit::TestCase
  ResponseCodeStub = Struct.new(:code)
  RedirectResponseStub = Struct.new(:code, :Location)

  def setup
    @conn = ActiveResource::Connection.new('http://localhost')
    matz  = { :person => { :id => 1, :name => 'Matz' } }
    david = { :person => { :id => 2, :name => 'David' } }
    @people = { :people => [ matz, david ] }.to_json
    @people_single = { 'people-single-elements' => [ matz ] }.to_json
    @people_empty = { 'people-empty-elements' => [ ] }.to_json
    @matz  = matz.to_json
    @david = david.to_json
    @header = { 'key' => 'value' }.freeze

    @default_request_headers = { 'Content-Type' => 'application/json' }
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/people/2.json", @header, @david
      mock.get    "/people.json", {}, @people
      mock.get    "/people_single_elements.json", {}, @people_single
      mock.get    "/people_empty_elements.json", {}, @people_empty
      mock.get    "/people/1.json", {}, @matz
      mock.put    "/people/1.json", {}, nil, 204
      mock.put    "/people/2.json", {}, @header, 204
      mock.delete "/people/1.json", {}, nil, 200
      mock.delete "/people/2.json", @header, nil, 200
      mock.post   "/people.json",   {}, nil, 201, 'Location' => '/people/5.json'
      mock.post   "/members.json",  {}, @header, 201, 'Location' => '/people/6.json'
      mock.head   "/people/1.json", {}, nil, 200
    end
  end

  def test_handle_response
    # 2xx and 3xx are valid responses.
    [200, 299, 300, 399].each do |code|
      expected = ResponseCodeStub.new(code)
      assert_equal expected, handle_response(expected)
    end

    # 301 is moved permanently (redirect)
    assert_redirect_raises 301

    # 302 is found (redirect)
    assert_redirect_raises 302

    # 303 is see other (redirect)
    assert_redirect_raises 303

    # 307 is temporary redirect
    assert_redirect_raises 307

    # 400 is a bad request (e.g. malformed URI or missing request parameter)
    assert_response_raises ActiveResource::BadRequest, 400

    # 401 is an unauthorized request
    assert_response_raises ActiveResource::UnauthorizedAccess, 401

    # 403 is a forbidden request (and authorizing will not help)
    assert_response_raises ActiveResource::ForbiddenAccess, 403

    # 404 is a missing resource.
    assert_response_raises ActiveResource::ResourceNotFound, 404

    # 405 is a method not allowed error
    assert_response_raises ActiveResource::MethodNotAllowed, 405

    # 409 is an optimistic locking error
    assert_response_raises ActiveResource::ResourceConflict, 409

    # 410 is a removed resource
    assert_response_raises ActiveResource::ResourceGone, 410

    # 422 is a validation error
    assert_response_raises ActiveResource::ResourceInvalid, 422

    # 4xx are client errors.
    [402, 499].each do |code|
      assert_response_raises ActiveResource::ClientError, code
    end

    # 5xx are server errors.
    [500, 599].each do |code|
      assert_response_raises ActiveResource::ServerError, code
    end

    # Others are unknown.
    [199, 600].each do |code|
      assert_response_raises ActiveResource::ConnectionError, code
    end
  end

  ResponseHeaderStub = Struct.new(:code, :message, 'Allow')
  def test_should_return_allowed_methods_for_method_no_allowed_exception
    begin
      handle_response ResponseHeaderStub.new(405, "HTTP Failed...", "GET, POST")
    rescue ActiveResource::MethodNotAllowed => e
      assert_equal "Failed.  Response code = 405.  Response message = HTTP Failed....", e.message
      assert_equal [:get, :post], e.allowed_methods
    end
  end

  def test_initialize_raises_argument_error_on_missing_site
    assert_raise(ArgumentError) { ActiveResource::Connection.new(nil) }
  end

  def test_site_accessor_accepts_uri_or_string_argument
    site = URI.parse("http://localhost")

    assert_raise(URI::InvalidURIError) { @conn.site = nil }

    assert_nothing_raised { @conn.site = "http://localhost" }
    assert_equal site, @conn.site

    assert_nothing_raised { @conn.site = site }
    assert_equal site, @conn.site
  end

  def test_proxy_accessor_accepts_uri_or_string_argument
    proxy = URI.parse("http://proxy_user:proxy_password@proxy.local:4242")

    assert_nothing_raised { @conn.proxy = "http://proxy_user:proxy_password@proxy.local:4242" }
    assert_equal proxy, @conn.proxy

    assert_nothing_raised { @conn.proxy = proxy }
    assert_equal proxy, @conn.proxy
  end

  def test_timeout_accessor
    @conn.timeout = 5
    assert_equal 5, @conn.timeout
  end

  def test_get
    matz = decode(@conn.get("/people/1.json"))
    assert_equal "Matz", matz["name"]
  end

  def test_head
    response = @conn.head("/people/1.json")
    assert response.body.blank?
    assert_equal 200, response.code
  end

  def test_get_with_header
    david = decode(@conn.get("/people/2.json", @header))
    assert_equal "David", david["name"]
  end

  def test_get_collection
    people = decode(@conn.get("/people.json"))
    assert_equal "Matz", people[0]["person"]["name"]
    assert_equal "David", people[1]["person"]["name"]
  end

  def test_get_collection_single
    people = decode(@conn.get("/people_single_elements.json"))
    assert_equal "Matz", people[0]["person"]["name"]
  end

  def test_get_collection_empty
    people = decode(@conn.get("/people_empty_elements.json"))
    assert_equal [], people
  end

  def test_post
    response = @conn.post("/people.json")
    assert_equal "/people/5.json", response["Location"]
  end

  def test_post_with_header
    response = @conn.post("/members.json", @header)
    assert_equal "/people/6.json", response["Location"]
  end

  def test_put
    response = @conn.put("/people/1.json")
    assert_equal 204, response.code
  end

  def test_put_with_header
    response = @conn.put("/people/2.json", @header)
    assert_equal 204, response.code
  end

  def test_delete
    response = @conn.delete("/people/1.json")
    assert_equal 200, response.code
  end

  def test_delete_with_header
    response = @conn.delete("/people/2.json", @header)
    assert_equal 200, response.code
  end

  def test_timeout
    @http = mock('new Net::HTTP')
    @conn.expects(:http).returns(@http)
    @http.expects(:get).raises(Timeout::Error, 'execution expired')
    assert_raise(ActiveResource::TimeoutError) { @conn.get('/people_timeout.json') }
  end

  def test_setting_timeout
    http = Net::HTTP.new('')

    [10, 20].each do |timeout|
      @conn.timeout = timeout
      @conn.send(:configure_http, http)
      assert_equal timeout, http.open_timeout
      assert_equal timeout, http.read_timeout
    end
  end

  def test_accept_http_header
    @http = mock('new Net::HTTP')
    @conn.expects(:http).returns(@http)
    path = '/people/1.xml'
    @http.expects(:get).with(path, { 'Accept' => 'application/xhtml+xml' }).returns(ActiveResource::Response.new(@matz, 200, { 'Content-Type' => 'text/xhtml' }))
    assert_nothing_raised(Mocha::ExpectationError) { @conn.get(path, { 'Accept' => 'application/xhtml+xml' }) }
  end

  def test_ssl_options_get_applied_to_http
    http = Net::HTTP.new('')
    @conn.site="https://secure"
    @conn.ssl_options={:verify_mode => OpenSSL::SSL::VERIFY_PEER}
    @conn.timeout = 10 # prevent warning about uninitialized.
    @conn.send(:configure_http, http)

    assert http.use_ssl?
    assert_equal http.verify_mode, OpenSSL::SSL::VERIFY_PEER
  end

  def test_ssl_error
    http = Net::HTTP.new('')
    @conn.expects(:http).returns(http)
    http.expects(:get).raises(OpenSSL::SSL::SSLError, 'Expired certificate')
    assert_raise(ActiveResource::SSLError) { @conn.get('/people/1.json') }
  end

  def test_auth_type_can_be_string
    @conn.auth_type = 'digest'
    assert_equal(:digest, @conn.auth_type)
  end

  def test_auth_type_defaults_to_basic
    @conn.auth_type = nil
    assert_equal(:basic, @conn.auth_type)
  end

  def test_auth_type_ignores_nonsensical_values
    @conn.auth_type = :wibble
    assert_equal(:basic, @conn.auth_type)
  end

  protected
    def assert_response_raises(klass, code)
      assert_raise(klass, "Expected response code #{code} to raise #{klass}") do
        handle_response ResponseCodeStub.new(code)
      end
    end

    def assert_redirect_raises(code)
      assert_raise(ActiveResource::Redirection, "Expected response code #{code} to raise ActiveResource::Redirection") do
        handle_response RedirectResponseStub.new(code, 'http://example.com/')
      end
    end

    def handle_response(response)
      @conn.__send__(:handle_response, response)
    end

    def decode(response)
      @conn.format.decode(response.body)
    end
end
