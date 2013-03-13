require 'abstract_unit'

class HeaderTest < ActiveSupport::TestCase
  def setup
    @headers = ActionDispatch::Http::Headers.new(
      "CONTENT_TYPE" => "text/plain",
      "HTTP_REFERER" => "/some/page"
    )
  end

  def test_each
    headers = []
    @headers.each { |pair| headers << pair }
    assert_equal [["CONTENT_TYPE", "text/plain"],
                  ["HTTP_REFERER", "/some/page"]], headers
  end

  def test_setter
    @headers['foo'] = "bar"
    assert_equal "bar", @headers['foo']
  end

  def test_key?
    assert @headers.key?('CONTENT_TYPE')
    assert @headers.include?('CONTENT_TYPE')
  end

  def test_fetch_with_block
    assert_equal 'omg', @headers.fetch('notthere') { 'omg' }
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
    assert_equal "not found", @headers.fetch('not-found', 'not found')
  end
end
