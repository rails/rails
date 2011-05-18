require 'abstract_unit'
require 'active_support/core_ext/object/inclusion'

class HttpMockTest < ActiveSupport::TestCase
  setup do
    @http = ActiveResource::HttpMock.new("http://example.com")
  end

  FORMAT_HEADER = ActiveResource::Connection::HTTP_FORMAT_HEADER_NAMES

  [:post, :put, :get, :delete, :head].each do |method|
    test "responds to simple #{method} request" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.send(method, "/people/1", { FORMAT_HEADER[method] => "application/json" }, "Response")
      end

      assert_equal "Response", request(method, "/people/1", FORMAT_HEADER[method] => "application/json").body
    end

    test "adds format header by default to #{method} request" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.send(method, "/people/1", {}, "Response")
      end

      assert_equal "Response", request(method, "/people/1", FORMAT_HEADER[method] => "application/json").body
    end

    test "respond only when headers match header by default to #{method} request" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.send(method, "/people/1", {"X-Header" => "X"}, "Response")
      end

      assert_equal "Response", request(method, "/people/1", "X-Header" => "X").body
      assert_raise(ActiveResource::InvalidRequestError) { request(method, "/people/1") }
    end

    test "does not overwrite format header to #{method} request" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.send(method, "/people/1", {FORMAT_HEADER[method] => "application/json"}, "Response")
      end

      assert_equal "Response", request(method, "/people/1", FORMAT_HEADER[method] => "application/json").body
    end

    test "ignores format header when there is only one response to same url in a #{method} request" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.send(method, "/people/1", {}, "Response")
      end

      assert_equal "Response", request(method, "/people/1", FORMAT_HEADER[method] => "application/json").body
      assert_equal "Response", request(method, "/people/1", FORMAT_HEADER[method] => "application/xml").body
    end

    test "responds correctly when format header is given to #{method} request" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.send(method, "/people/1", { FORMAT_HEADER[method] => "application/xml" }, "XML")
        mock.send(method, "/people/1", { FORMAT_HEADER[method] => "application/json" }, "Json")
      end

      assert_equal "XML", request(method, "/people/1", FORMAT_HEADER[method] => "application/xml").body
      assert_equal "Json", request(method, "/people/1", FORMAT_HEADER[method] => "application/json").body
    end

    test "raises InvalidRequestError if no response found for the #{method} request" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.send(method, "/people/1", { FORMAT_HEADER[method] => "application/json" }, "json")
      end

      assert_raise(::ActiveResource::InvalidRequestError) do
        request(method, "/people/1", FORMAT_HEADER[method] => "application/xml")
      end
    end

  end

  test "allows you to send in pairs directly to the respond_to method" do
    matz  = { :person => { :id => 1, :name => "Matz" } }.to_json

    create_matz = ActiveResource::Request.new(:post, '/people.json', matz, {})
    created_response = ActiveResource::Response.new("", 201, { "Location" => "/people/1.json" })
    get_matz = ActiveResource::Request.new(:get, '/people/1.json', nil)
    ok_response = ActiveResource::Response.new(matz, 200, {})

    pairs = {create_matz => created_response, get_matz => ok_response}

    ActiveResource::HttpMock.respond_to(pairs)
    assert_equal 2, ActiveResource::HttpMock.responses.length
    assert_equal "", ActiveResource::HttpMock.responses.assoc(create_matz)[1].body
    assert_equal matz, ActiveResource::HttpMock.responses.assoc(get_matz)[1].body
  end

  test "resets all mocked responses on each call to respond_to with a block by default" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "JSON1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/2", {}, "JSON2")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length
  end

  test "resets all mocked responses on each call to respond_to by passing pairs by default" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "JSON1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    matz  = { :person => { :id => 1, :name => "Matz" } }.to_json
    get_matz = ActiveResource::Request.new(:get, '/people/1.json', nil)
    ok_response = ActiveResource::Response.new(matz, 200, {})
    ActiveResource::HttpMock.respond_to({get_matz => ok_response})

    assert_equal 1, ActiveResource::HttpMock.responses.length
  end

  test "allows you to add new responses to the existing responses by calling a block" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "JSON1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    ActiveResource::HttpMock.respond_to(false) do |mock|
      mock.send(:get, "/people/2", {}, "JSON2")
    end
    assert_equal 2, ActiveResource::HttpMock.responses.length
  end

  test "allows you to add new responses to the existing responses by passing pairs" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "JSON1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    matz  = { :person => { :id => 1, :name => "Matz" } }.to_json
    get_matz = ActiveResource::Request.new(:get, '/people/1.json', nil)
    ok_response = ActiveResource::Response.new(matz, 200, {})
    ActiveResource::HttpMock.respond_to({get_matz => ok_response}, false)

    assert_equal 2, ActiveResource::HttpMock.responses.length
  end

  test "allows you to replace the existing reponse with the same request by calling a block" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "JSON1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    ActiveResource::HttpMock.respond_to(false) do |mock|
      mock.send(:get, "/people/1", {}, "JSON2")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length
  end

  test "allows you to replace the existing reponse with the same request by passing pairs" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "JSON1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    matz  = { :person => { :id => 1, :name => "Matz" } }.to_json
    get_matz = ActiveResource::Request.new(:get, '/people/1', nil)
    ok_response = ActiveResource::Response.new(matz, 200, {})

    ActiveResource::HttpMock.respond_to({get_matz => ok_response}, false)
    assert_equal 1, ActiveResource::HttpMock.responses.length
  end

  test "do not replace the response with the same path but different method by calling a block" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "JSON1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    ActiveResource::HttpMock.respond_to(false) do |mock|
      mock.send(:put, "/people/1", {}, "JSON2")
    end
    assert_equal 2, ActiveResource::HttpMock.responses.length
  end

  test "do not replace the response with the same path but different method by passing pairs" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "JSON1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    put_matz = ActiveResource::Request.new(:put, '/people/1', nil)
    ok_response = ActiveResource::Response.new("", 200, {})

    ActiveResource::HttpMock.respond_to({put_matz => ok_response}, false)
    assert_equal 2, ActiveResource::HttpMock.responses.length
  end

  def request(method, path, headers = {}, body = nil)
    if method.in?([:put, :post])
      @http.send(method, path, body, headers)
    else
      @http.send(method, path, headers)
    end
  end
end
