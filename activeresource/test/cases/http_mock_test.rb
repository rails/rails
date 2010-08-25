require 'abstract_unit'

class HttpMockTest < ActiveSupport::TestCase
  setup do
    @http = ActiveResource::HttpMock.new("http://example.com")
  end

  FORMAT_HEADER = ActiveResource::Connection::HTTP_FORMAT_HEADER_NAMES

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

  def request(method, path, headers = {}, body = nil)
    if [:put, :post].include? method
      @http.send(method, path, body, headers)
    else
      @http.send(method, path, headers)
    end
  end
end
