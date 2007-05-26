require "#{File.dirname(__FILE__)}/abstract_unit"
require 'base64'

class ConnectionTest < Test::Unit::TestCase
  ResponseCodeStub = Struct.new(:code)

  def setup
    @conn = ActiveResource::Connection.new('http://localhost')
    @matz  = { :id => 1, :name => 'Matz' }
    @david = { :id => 2, :name => 'David' }
    @people = [ @matz, @david ].to_xml(:root => 'people')
    @people_single = [ @matz ].to_xml(:root => 'people-single-elements')
    @people_empty = [ ].to_xml(:root => 'people-empty-elements')
    @matz = @matz.to_xml(:root => 'person')
    @david = @david.to_xml(:root => 'person')
    @header = {'key' => 'value'}

    @default_request_headers = { 'Content-Type' => 'application/xml' }
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/people/2.xml", @header, @david
      mock.get    "/people.xml", {}, @people
      mock.get    "/people_single_elements.xml", {}, @people_single
      mock.get    "/people_empty_elements.xml", {}, @people_empty
      mock.get    "/people/1.xml", {}, @matz
      mock.put    "/people/1.xml", {}, nil, 204
      mock.put    "/people/2.xml", {}, @header, 204
      mock.delete "/people/1.xml", {}, nil, 200
      mock.delete "/people/2.xml", @header, nil, 200
      mock.post   "/people.xml",   {}, nil, 201, 'Location' => '/people/5.xml'
      mock.post   "/members.xml",  {}, @header, 201, 'Location' => '/people/6.xml'
    end
  end

  def test_handle_response
    # 2xx and 3xx are valid responses.
    [200, 299, 300, 399].each do |code|
      expected = ResponseCodeStub.new(code)
      assert_equal expected, handle_response(expected)
    end

    # 404 is a missing resource.
    assert_response_raises ActiveResource::ResourceNotFound, 404

    # 405 is a missing not allowed error
    assert_response_raises ActiveResource::MethodNotAllowed, 405

    # 409 is an optimistic locking error
    assert_response_raises ActiveResource::ResourceConflict, 409

    # 422 is a validation error
    assert_response_raises ActiveResource::ResourceInvalid, 422

    # 4xx are client errors.
    [401, 499].each do |code|
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

  ResponseHeaderStub = Struct.new(:code, 'Allow')
  def test_should_return_allowed_methods_for_method_no_allowed_exception
    begin
      handle_response ResponseHeaderStub.new(405, "GET, POST")
    rescue ActiveResource::MethodNotAllowed => e
      assert_equal "Failed with 405", e.message
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

  def test_get
    matz = @conn.get("/people/1.xml")
    assert_equal "Matz", matz["name"]
  end

  def test_get_with_header
    david = @conn.get("/people/2.xml", @header)
    assert_equal "David", david["name"]
  end

  def test_get_collection
    people = @conn.get("/people.xml")
    assert_equal "Matz", people[0]["name"]
    assert_equal "David", people[1]["name"]
  end
  
  def test_get_collection_single
    people = @conn.get("/people_single_elements.xml")
    assert_equal "Matz", people[0]["name"]
  end
  
  def test_get_collection_empty
    people = @conn.get("/people_empty_elements.xml")
    assert_nil people
  end

  def test_post
    response = @conn.post("/people.xml")
    assert_equal "/people/5.xml", response["Location"]
  end

  def test_post_with_header
    response = @conn.post("/members.xml", @header)
    assert_equal "/people/6.xml", response["Location"]
  end

  def test_put
    response = @conn.put("/people/1.xml")
    assert_equal 204, response.code
  end

  def test_put_with_header
    response = @conn.put("/people/2.xml", @header)
    assert_equal 204, response.code
  end

  def test_delete
    response = @conn.delete("/people/1.xml")
    assert_equal 200, response.code
  end

  def test_delete_with_header
    response = @conn.delete("/people/2.xml", @header)
    assert_equal 200, response.code
  end

  protected
    def assert_response_raises(klass, code)
      assert_raise(klass, "Expected response code #{code} to raise #{klass}") do
        handle_response ResponseCodeStub.new(code)
      end
    end

    def handle_response(response)
      @conn.send(:handle_response, response)
    end
end
