require "#{File.dirname(__FILE__)}/abstract_unit"
require 'base64'

class AuthorizationTest < Test::Unit::TestCase
  Response = Struct.new(:code)

  def setup
    @conn = ActiveResource::Connection.new('http://localhost')
    @matz  = { :id => 1, :name => 'Matz' }.to_xml(:root => 'person')
    @david = { :id => 2, :name => 'David' }.to_xml(:root => 'person')
    @authenticated_conn = ActiveResource::Connection.new("http://david:test123@localhost")
    @authorization_request_header = { 'Authorization' => 'Basic ZGF2aWQ6dGVzdDEyMw==' }

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/people/2.xml",           @authorization_request_header, @david
      mock.put    "/people/2.xml",           @authorization_request_header, nil, 204
      mock.delete "/people/2.xml",           @authorization_request_header, nil, 200
      mock.post   "/people/2/addresses.xml", @authorization_request_header, nil, 201, 'Location' => '/people/1/addresses/5'
    end
  end

  def test_authorization_header
    authorization_header = @authenticated_conn.send(:authorization_header)
    assert_equal @authorization_request_header['Authorization'], authorization_header['Authorization']
    authorization = authorization_header["Authorization"].to_s.split
    
    assert_equal "Basic", authorization[0]
    assert_equal ["david", "test123"], Base64.decode64(authorization[1]).split(":")[0..1]
  end
  
  def test_authorization_header_with_username_but_no_password
    @conn = ActiveResource::Connection.new("http://david:@localhost")
    authorization_header = @conn.send(:authorization_header)
    authorization = authorization_header["Authorization"].to_s.split
    
    assert_equal "Basic", authorization[0]
    assert_equal ["david"], Base64.decode64(authorization[1]).split(":")[0..1]
  end
  
  def test_authorization_header_with_password_but_no_username
    @conn = ActiveResource::Connection.new("http://:test123@localhost")
    authorization_header = @conn.send(:authorization_header)
    authorization = authorization_header["Authorization"].to_s.split
    
    assert_equal "Basic", authorization[0]
    assert_equal ["", "test123"], Base64.decode64(authorization[1]).split(":")[0..1]
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

  def test_raises_invalid_request_on_unauthorized_requests
    assert_raises(ActiveResource::InvalidRequestError) { @conn.post("/people/2.xml") }
    assert_raises(ActiveResource::InvalidRequestError) { @conn.post("/people/2/addresses.xml") }
    assert_raises(ActiveResource::InvalidRequestError) { @conn.put("/people/2.xml") }
    assert_raises(ActiveResource::InvalidRequestError) { @conn.delete("/people/2.xml") }
  end

  protected
    def assert_response_raises(klass, code)
      assert_raise(klass, "Expected response code #{code} to raise #{klass}") do
        @conn.send(:handle_response, Response.new(code))
      end
    end
end
