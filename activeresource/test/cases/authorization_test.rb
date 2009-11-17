require 'abstract_unit'

class AuthorizationTest < Test::Unit::TestCase
  Response = Struct.new(:code)

  def setup
    @conn = ActiveResource::Connection.new('http://localhost')
    @matz  = { :id => 1, :name => 'Matz' }.to_xml(:root => 'person')
    @david = { :id => 2, :name => 'David' }.to_xml(:root => 'person')
    @authenticated_conn = ActiveResource::Connection.new("http://david:test123@localhost")
    @basic_authorization_request_header = { 'Authorization' => 'Basic ZGF2aWQ6dGVzdDEyMw==' }

    @nonce = "MTI0OTUxMzc4NzpjYWI3NDM3NDNmY2JmODU4ZjQ2ZjcwNGZkMTJiMjE0NA=="

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/people/2.xml",           @basic_authorization_request_header, @david
      mock.get    "/people/1.xml",           @basic_authorization_request_header, nil, 401, { 'WWW-Authenticate' => 'i_should_be_ignored' }
      mock.put    "/people/2.xml",           @basic_authorization_request_header, nil, 204
      mock.delete "/people/2.xml",           @basic_authorization_request_header, nil, 200
      mock.post   "/people/2/addresses.xml", @basic_authorization_request_header, nil, 201, 'Location' => '/people/1/addresses/5'
      mock.head   "/people/2.xml",           @basic_authorization_request_header, nil, 200

      mock.get    "/people/2.xml",           { 'Authorization' => blank_digest_auth_header("/people/2.xml", "a10c9bd131c9d4d7755b8f4706fd04af") }, nil, 401, { 'WWW-Authenticate' => response_digest_auth_header }
      mock.get    "/people/2.xml",           { 'Authorization' => request_digest_auth_header("/people/2.xml", "912c7a643f18cda562b8d9662c47b6f5") }, @david, 200
      mock.get    "/people/1.xml",           { 'Authorization' => request_digest_auth_header("/people/1.xml", "d76e675c0ecfa2bb1abe01491b068a06") }, @matz, 200

      mock.put    "/people/2.xml",           { 'Authorization' => blank_digest_auth_header("/people/2.xml", "7de8a265a5be3c4c2d3a246562ecd6bd") }, nil, 401, { 'WWW-Authenticate' => response_digest_auth_header }
      mock.put    "/people/2.xml",           { 'Authorization' => request_digest_auth_header("/people/2.xml", "3fb3b33d9d0b869cc75815aa11faacd9") }, nil, 204

      mock.delete "/people/2.xml",           { 'Authorization' => blank_digest_auth_header("/people/2.xml", "07dfc32769a34ea3510d3a77d64ca495") }, nil, 401, { 'WWW-Authenticate' => response_digest_auth_header }
      mock.delete "/people/2.xml",           { 'Authorization' => request_digest_auth_header("/people/2.xml", "5d438610de7ec163b29096c9afcbb254") }, nil, 200

      mock.post   "/people/2/addresses.xml", { 'Authorization' => blank_digest_auth_header("/people/2/addresses.xml", "966dab13620421f928d051f2b9d7b9af") }, nil, 401, { 'WWW-Authenticate' => response_digest_auth_header }
      mock.post   "/people/2/addresses.xml", { 'Authorization' => request_digest_auth_header("/people/2/addresses.xml", "ed540d032c63f8ee34959116c090ec45") }, nil, 201, 'Location' => '/people/1/addresses/5'

      mock.head   "/people/2.xml",           { 'Authorization' => blank_digest_auth_header("/people/2.xml", "2854eeb92cce2aed29350ea0ce7ba1e2") }, nil, 401, { 'WWW-Authenticate' => response_digest_auth_header }
      mock.head   "/people/2.xml",           { 'Authorization' => request_digest_auth_header("/people/2.xml", "07cd4d247e9c130f92ba2501a080b328") }, nil, 200
    end

    # Make client nonce deterministic
    class << @authenticated_conn
      private

      def client_nonce
        'i-am-a-client-nonce'
      end
    end
  end

  def test_authorization_header
    authorization_header = @authenticated_conn.__send__(:authorization_header, :get, URI.parse('/people/2.xml'))
    assert_equal @basic_authorization_request_header['Authorization'], authorization_header['Authorization']
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["david", "test123"], ActiveSupport::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_with_username_but_no_password
    @conn = ActiveResource::Connection.new("http://david:@localhost")
    authorization_header = @conn.__send__(:authorization_header, :get, URI.parse('/people/2.xml'))
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["david"], ActiveSupport::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_with_password_but_no_username
    @conn = ActiveResource::Connection.new("http://:test123@localhost")
    authorization_header = @conn.__send__(:authorization_header, :get, URI.parse('/people/2.xml'))
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["", "test123"], ActiveSupport::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_with_decoded_credentials_from_url
    @conn = ActiveResource::Connection.new("http://my%40email.com:%31%32%33@localhost")
    authorization_header = @conn.__send__(:authorization_header, :get, URI.parse('/people/2.xml'))
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["my@email.com", "123"], ActiveSupport::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_explicitly_setting_username_and_password
    @authenticated_conn = ActiveResource::Connection.new("http://@localhost")
    @authenticated_conn.user = 'david'
    @authenticated_conn.password = 'test123'
    authorization_header = @authenticated_conn.__send__(:authorization_header, :get, URI.parse('/people/2.xml'))
    assert_equal @basic_authorization_request_header['Authorization'], authorization_header['Authorization']
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["david", "test123"], ActiveSupport::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_explicitly_setting_username_but_no_password
    @conn = ActiveResource::Connection.new("http://@localhost")
    @conn.user = "david"
    authorization_header = @conn.__send__(:authorization_header, :get, URI.parse('/people/2.xml'))
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["david"], ActiveSupport::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_explicitly_setting_password_but_no_username
    @conn = ActiveResource::Connection.new("http://@localhost")
    @conn.password = "test123"
    authorization_header = @conn.__send__(:authorization_header, :get, URI.parse('/people/2.xml'))
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["", "test123"], ActiveSupport::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_if_credentials_supplied_and_auth_type_is_basic
    @authenticated_conn.auth_type = :basic
    authorization_header = @authenticated_conn.__send__(:authorization_header, :get, URI.parse('/people/2.xml'))
    assert_equal @basic_authorization_request_header['Authorization'], authorization_header['Authorization']
    authorization = authorization_header["Authorization"].to_s.split

    assert_equal "Basic", authorization[0]
    assert_equal ["david", "test123"], ActiveSupport::Base64.decode64(authorization[1]).split(":")[0..1]
  end

  def test_authorization_header_if_credentials_supplied_and_auth_type_is_digest
    @authenticated_conn.auth_type = :digest
    authorization_header = @authenticated_conn.__send__(:authorization_header, :get, URI.parse('/people/2.xml'))
    assert_equal blank_digest_auth_header("/people/2.xml", "a10c9bd131c9d4d7755b8f4706fd04af"), authorization_header['Authorization']
  end

  def test_get
    david = @authenticated_conn.get("/people/2.xml")
    assert_equal "David", david["name"]
  end

  def test_post
    response = @authenticated_conn.post("/people/2/addresses.xml")
    assert_equal "/people/1/addresses/5", response["Location"]
  end

  def test_put
    response = @authenticated_conn.put("/people/2.xml")
    assert_equal 204, response.code
  end

  def test_delete
    response = @authenticated_conn.delete("/people/2.xml")
    assert_equal 200, response.code
  end

  def test_head
    response = @authenticated_conn.head("/people/2.xml")
    assert_equal 200, response.code
  end

  def test_get_with_digest_auth_handles_initial_401_response_and_retries
    @authenticated_conn.auth_type = :digest
    response = @authenticated_conn.get("/people/2.xml")
    assert_equal "David", response["name"]
  end

  def test_post_with_digest_auth_handles_initial_401_response_and_retries
    @authenticated_conn.auth_type = :digest
    response = @authenticated_conn.post("/people/2/addresses.xml")
    assert_equal "/people/1/addresses/5", response["Location"]
    assert_equal 201, response.code
  end

  def test_put_with_digest_auth_handles_initial_401_response_and_retries
     @authenticated_conn.auth_type = :digest
     response = @authenticated_conn.put("/people/2.xml")
     assert_equal 204, response.code
  end

  def test_delete_with_digest_auth_handles_initial_401_response_and_retries
    @authenticated_conn.auth_type = :digest
    response = @authenticated_conn.delete("/people/2.xml")
    assert_equal 200, response.code
  end

  def test_head_with_digest_auth_handles_initial_401_response_and_retries
    @authenticated_conn.auth_type = :digest
    response = @authenticated_conn.head("/people/2.xml")
    assert_equal 200, response.code
  end

  def test_get_with_digest_auth_caches_nonce
    @authenticated_conn.auth_type = :digest
    response = @authenticated_conn.get("/people/2.xml")
    assert_equal "David", response["name"]

    # There is no mock for this request with a non-cached nonce.
    response = @authenticated_conn.get("/people/1.xml")
    assert_equal "Matz", response["name"]
  end

  def test_retry_on_401_only_happens_with_digest_auth
    assert_raise(ActiveResource::UnauthorizedAccess) { @authenticated_conn.get("/people/1.xml") }
    assert_equal "", @authenticated_conn.send(:response_auth_header)
  end

  def test_raises_invalid_request_on_unauthorized_requests
    assert_raise(ActiveResource::InvalidRequestError) { @conn.get("/people/2.xml") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.post("/people/2/addresses.xml") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.put("/people/2.xml") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.delete("/people/2.xml") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.head("/people/2.xml") }
  end

  def test_raises_invalid_request_on_unauthorized_requests_with_digest_auth
    @conn.auth_type = :digest
    assert_raise(ActiveResource::InvalidRequestError) { @conn.get("/people/2.xml") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.post("/people/2/addresses.xml") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.put("/people/2.xml") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.delete("/people/2.xml") }
    assert_raise(ActiveResource::InvalidRequestError) { @conn.head("/people/2.xml") }
  end

  def test_client_nonce_is_not_nil
    assert_not_nil ActiveResource::Connection.new("http://david:test123@localhost").send(:client_nonce)
  end

  protected
    def assert_response_raises(klass, code)
      assert_raise(klass, "Expected response code #{code} to raise #{klass}") do
        @conn.__send__(:handle_response, Response.new(code))
      end
    end

    def blank_digest_auth_header(uri, response)
      %Q(Digest username="david", realm="", qop="", uri="#{uri}", nonce="", nc="0", cnonce="i-am-a-client-nonce", opaque="", response="#{response}")
    end

    def request_digest_auth_header(uri, response)
      %Q(Digest username="david", realm="RailsTestApp", qop="auth", uri="#{uri}", nonce="#{@nonce}", nc="0", cnonce="i-am-a-client-nonce", opaque="ef6dfb078ba22298d366f99567814ffb", response="#{response}")
    end

    def response_digest_auth_header
      %Q(Digest realm="RailsTestApp", qop="auth", algorithm=MD5, nonce="#{@nonce}", opaque="ef6dfb078ba22298d366f99567814ffb")
    end
end
