require 'abstract_unit'

class HeaderTest < ActiveSupport::TestCase
  def setup
    @headers = ActionDispatch::Http::Headers.new(
      "HTTP_CONTENT_TYPE" => "text/plain"
    )
  end

  def test_each
    headers = []
    @headers.each { |pair| headers << pair }
    assert_equal [["HTTP_CONTENT_TYPE", "text/plain"]], headers
  end

  def test_setter
    @headers['foo'] = "bar"
    assert_equal "bar", @headers['foo']
  end

  def test_key?
    assert @headers.key?('HTTP_CONTENT_TYPE')
    assert @headers.include?('HTTP_CONTENT_TYPE')
  end

  def test_fetch_with_block
    assert_equal 'omg', @headers.fetch('notthere') { 'omg' }
  end

  test "content type" do
    assert_equal "text/plain", @headers["Content-Type"]
    assert_equal "text/plain", @headers["content-type"]
    assert_equal "text/plain", @headers["CONTENT_TYPE"]
    assert_equal "text/plain", @headers["HTTP_CONTENT_TYPE"]
  end

  test "fetch" do
    assert_equal "text/plain", @headers.fetch("content-type", nil)
    assert_equal "not found", @headers.fetch('not-found', 'not found')
  end
end
