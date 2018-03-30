# frozen_string_literal: true

require "abstract_unit"

class HeaderTest < ActiveSupport::TestCase
  def make_headers(hash)
    ActionDispatch::Http::Headers.new ActionDispatch::Request.new hash
  end

  setup do
    @headers = make_headers(
      "CONTENT_TYPE" => "text/plain",
      "HTTP_REFERER" => "/some/page"
    )
  end

  test "#new does not normalize the data" do
    headers = make_headers(
      "Content-Type" => "application/json",
      "HTTP_REFERER" => "/some/page",
      "Host" => "http://test.com")

    assert_equal({ "Content-Type" => "application/json",
                  "HTTP_REFERER" => "/some/page",
                  "Host" => "http://test.com" }, headers.env)
  end

  test "#env returns the headers as env variables" do
    assert_equal({ "CONTENT_TYPE" => "text/plain",
                  "HTTP_REFERER" => "/some/page" }, @headers.env)
  end

  test "#each iterates through the env variables" do
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

  test "add to multivalued headers" do
    # Sets header when not present
    @headers.add "Foo", "1"
    assert_equal "1", @headers["Foo"]

    # Ignores nil values
    @headers.add "Foo", nil
    assert_equal "1", @headers["Foo"]

    # Converts value to string
    @headers.add "Foo", 1
    assert_equal "1,1", @headers["Foo"]

    # Case-insensitive
    @headers.add "fOo", 2
    assert_equal "1,1,2", @headers["foO"]
  end

  test "headers can contain numbers" do
    @headers["Content-MD5"] = "Q2hlY2sgSW50ZWdyaXR5IQ=="

    assert_equal "Q2hlY2sgSW50ZWdyaXR5IQ==", @headers["Content-MD5"]
    assert_equal "Q2hlY2sgSW50ZWdyaXR5IQ==", @headers["HTTP_CONTENT_MD5"]
  end

  test "set new env variables" do
    @headers["HTTP_HOST"] = "127.0.0.1"

    assert_equal "127.0.0.1", @headers["Host"]
    assert_equal "127.0.0.1", @headers["HTTP_HOST"]
  end

  test "key?" do
    assert @headers.key?("CONTENT_TYPE")
    assert_includes @headers, "CONTENT_TYPE"
    assert @headers.key?("Content-Type")
    assert_includes @headers, "Content-Type"
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

  test "#merge! headers with mutation" do
    # rubocop:disable Performance/RedundantMerge
    @headers.merge!("Host" => "http://example.test",
                    "Content-Type" => "text/html")
    # rubocop:enable Performance/RedundantMerge
    assert_equal({ "HTTP_HOST" => "http://example.test",
                  "CONTENT_TYPE" => "text/html",
                  "HTTP_REFERER" => "/some/page" }, @headers.env)
  end

  test "#merge! env with mutation" do
    # rubocop:disable Performance/RedundantMerge
    @headers.merge!("HTTP_HOST" => "http://first.com",
                    "CONTENT_TYPE" => "text/html")
    # rubocop:enable Performance/RedundantMerge
    assert_equal({ "HTTP_HOST" => "http://first.com",
                  "CONTENT_TYPE" => "text/html",
                  "HTTP_REFERER" => "/some/page" }, @headers.env)
  end

  test "merge without mutation" do
    combined = @headers.merge("HTTP_HOST" => "http://example.com",
                              "CONTENT_TYPE" => "text/html")
    assert_equal({ "HTTP_HOST" => "http://example.com",
                  "CONTENT_TYPE" => "text/html",
                  "HTTP_REFERER" => "/some/page" }, combined.env)

    assert_equal({ "CONTENT_TYPE" => "text/plain",
                  "HTTP_REFERER" => "/some/page" }, @headers.env)
  end

  test "env variables with . are not modified" do
    headers = make_headers({})
    headers.merge! "rack.input" => "",
     "rack.request.cookie_hash" => "",
     "action_dispatch.logger" => ""

    assert_equal(["action_dispatch.logger",
                  "rack.input",
                  "rack.request.cookie_hash"], headers.env.keys.sort)
  end

  test "symbols are treated as strings" do
    headers = make_headers({})
    headers.merge!(:SERVER_NAME => "example.com",
                   "HTTP_REFERER" => "/",
                   :Host => "test.com")
    assert_equal "example.com", headers["SERVER_NAME"]
    assert_equal "/", headers[:HTTP_REFERER]
    assert_equal "test.com", headers["HTTP_HOST"]
  end

  test "headers directly modifies the passed environment" do
    env = { "HTTP_REFERER" => "/" }
    headers = make_headers(env)
    headers["Referer"] = "http://example.com/"
    headers["CONTENT_TYPE"] = "text/plain"
    assert_equal({ "HTTP_REFERER" => "http://example.com/",
                  "CONTENT_TYPE" => "text/plain" }, env)
  end

  test "fetch exception" do
    assert_raises KeyError do
      @headers.fetch(:some_key_that_doesnt_exist)
    end
  end
end
