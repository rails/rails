require "abstract_unit"

class HeaderTest < ActiveSupport::TestCase
  setup do
    @headers = ActionDispatch::Http::Headers.new(
      "CONTENT_TYPE" => "text/plain",
      "HTTP_REFERER" => "/some/page"
    )
  end

  test "each" do
    headers = []
    @headers.each { |pair| headers << pair }
    assert_equal [["CONTENT_TYPE", "text/plain"],
                  ["HTTP_REFERER", "/some/page"]], headers
  end

  test "set new headers" do
    @headers["Host"] = "127.0.0.1"

    assert_equal "127.0.0.1", @headers["Host"]
    assert_equal "127.0.0.1", @headers["HTTP_HOST"]
  end

  test "set new env variables" do
    @headers["HTTP_HOST"] = "127.0.0.1"

    assert_equal "127.0.0.1", @headers["Host"]
    assert_equal "127.0.0.1", @headers["HTTP_HOST"]
  end

  test "key?" do
    assert @headers.key?("CONTENT_TYPE")
    assert @headers.include?("CONTENT_TYPE")
  end

  test "fetch with block" do
    assert_equal "omg", @headers.fetch("notthere") { "omg" }
  end

  test "accessing http header" do
    assert_equal "/some/page", @headers["Referer"]
    assert_equal "/some/page", @headers["referer"]
    assert_equal "/some/page", @headers["HTTP_REFERER"]
  end

  test "accessing special header" do
    assert_equal "text/plain", @headers["Content-Type"]
    assert_equal "text/plain", @headers["content-type"]
    assert_equal "text/plain", @headers["CONTENT_TYPE"]
  end

  test "fetch" do
    assert_equal "text/plain", @headers.fetch("content-type", nil)
    assert_equal "not found", @headers.fetch("not-found", "not found")
  end
end
