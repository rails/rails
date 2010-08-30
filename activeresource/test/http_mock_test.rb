require 'abstract_unit'

class HttpMockTest < ActiveSupport::TestCase
  def setup
    @http = ActiveResource::HttpMock.new("http://example.com")
  end

  FORMAT_HEADER = { :get => 'Accept',
                    :put => 'Content-Type',
                    :post => 'Content-Type',
                    :delete => 'Accept',
                    :head => 'Accept'
                  }

  [:post, :put, :get, :delete, :head].each do |method|
    test "responds to simple #{method} request" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.send(method, "/people/1", {FORMAT_HEADER[method] => "application/xml"}, "Response")
      end

      assert_equal "Response", request(method, "/people/1", FORMAT_HEADER[method] => "application/xml").body
    end

    test "adds format header by default to #{method} request" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.send(method, "/people/1", {}, "Response")
      end

      assert_equal "Response", request(method, "/people/1", FORMAT_HEADER[method] => "application/xml").body
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
        mock.send(method, "/people/1", {FORMAT_HEADER[method] => "application/xml"}, "XML")
        mock.send(method, "/people/1", {FORMAT_HEADER[method] => "application/json"}, "Json")
      end

      assert_equal "XML", request(method, "/people/1", FORMAT_HEADER[method] => "application/xml").body
      assert_equal "Json", request(method, "/people/1", FORMAT_HEADER[method] => "application/json").body
    end

    test "raises InvalidRequestError if no response found for the #{method} request" do
      ActiveResource::HttpMock.respond_to do |mock|
        mock.send(method, "/people/1", {FORMAT_HEADER[method] => "application/xml"}, "XML")
      end

      assert_raise(::ActiveResource::InvalidRequestError) do
        request(method, "/people/1", FORMAT_HEADER[method] => "application/json")
      end
    end
    
  end

  test "allows you to send in pairs directly to the respond_to method" do
    matz  = { :id => 1, :name => "Matz" }.to_xml(:root => "person")
    
    create_matz = ActiveResource::Request.new(:post, '/people.xml', matz, {})
    created_response = ActiveResource::Response.new("", 201, {"Location" => "/people/1.xml"})
    get_matz = ActiveResource::Request.new(:get, '/people/1.xml', nil)
    ok_response = ActiveResource::Response.new(matz, 200, {})
    
    pairs = {create_matz => created_response, get_matz => ok_response}
    
    ActiveResource::HttpMock.respond_to(pairs)
    assert_equal 2, ActiveResource::HttpMock.responses.length
    assert_equal "", ActiveResource::HttpMock.responses.assoc(create_matz)[1].body
    assert_equal matz, ActiveResource::HttpMock.responses.assoc(get_matz)[1].body
  end

  test "resets all mocked responses on each call to respond_to with a block by default" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "XML1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/2", {}, "XML2")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length
  end

  test "resets all mocked responses on each call to respond_to by passing pairs by default" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "XML1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    matz  = { :id => 1, :name => "Matz" }.to_xml(:root => "person")
    get_matz = ActiveResource::Request.new(:get, '/people/1.xml', nil)
    ok_response = ActiveResource::Response.new(matz, 200, {})
    ActiveResource::HttpMock.respond_to({get_matz => ok_response})

    assert_equal 1, ActiveResource::HttpMock.responses.length
  end

  test "allows you to add new responses to the existing responses by calling a block" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "XML1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    ActiveResource::HttpMock.respond_to(false) do |mock|
      mock.send(:get, "/people/2", {}, "XML2")
    end
    assert_equal 2, ActiveResource::HttpMock.responses.length
  end

  test "allows you to add new responses to the existing responses by passing pairs" do
    ActiveResource::HttpMock.respond_to do |mock|
      mock.send(:get, "/people/1", {}, "XML1")
    end
    assert_equal 1, ActiveResource::HttpMock.responses.length

    matz  = { :id => 1, :name => "Matz" }.to_xml(:root => "person")
    get_matz = ActiveResource::Request.new(:get, '/people/1.xml', nil)
    ok_response = ActiveResource::Response.new(matz, 200, {})
    ActiveResource::HttpMock.respond_to({get_matz => ok_response}, false)

    assert_equal 2, ActiveResource::HttpMock.responses.length
  end

  def request(method, path, headers = {}, body = nil)
    if [:put, :post].include? method
      @http.send(method, path, body, headers)
    else
      @http.send(method, path, headers)
    end
  end
end
