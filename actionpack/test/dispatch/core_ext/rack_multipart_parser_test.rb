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
end
