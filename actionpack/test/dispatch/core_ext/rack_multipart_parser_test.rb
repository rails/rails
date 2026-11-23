# frozen_string_literal: true

require "abstract_unit"

class RackMultipartParserTest < ActiveSupport::TestCase
  test "ignore multipart encoding" do
    params = Rack::Multipart.parse_multipart({
      "REQUEST_METHOD" => "GET",
      "SERVER_NAME" => "example.org",
      "SERVER_PORT" => "80",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "QUERY_STRING" => "",
      "PATH_INFO" => "/",
      "rack.url_scheme" => "http",
      "HTTPS" => "off",
      "SCRIPT_NAME" => "",
      "rack.errors" => StringIO.new("".b),
      "rack.input" => StringIO.new("--AaB03x\r\ncontent-disposition: form-data; name=\"text\"\r\ncontent-type: text/plain; charset=ISO-8859-1\r\n\r\ncontents\r\n--AaB03x--\r\n".b),
      "CONTENT_LENGTH" => "123",
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x"
    })

    assert_equal 1, params.size
    assert_equal Encoding::BINARY, params.keys.first.encoding
    assert_equal Encoding::BINARY, params.values.first.encoding
  end

  test "ignore multipart filename encoding" do
    body = "--AaB03x\r\ncontent-disposition: form-data; name=\"file\"; filename*=ISO-8859-1''%DF%80.txt\r\ncontent-type: application/octet-stream\r\n\r\ncontents\r\n--AaB03x--\r\n".b
    params = Rack::Multipart.parse_multipart({
      "REQUEST_METHOD" => "POST",
      "rack.input" => StringIO.new(body),
      "CONTENT_LENGTH" => body.bytesize.to_s,
      "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x"
    })

    if params["file"].is_a?(Hash)
      assert_equal Encoding::BINARY, params["file"][:filename].encoding
    else
      pass # no longer parsed on newer versions of rack
    end
  end
end
