require 'abstract_unit'

class HeaderTest < ActiveSupport::TestCase
  def setup
    @headers = ActionDispatch::Http::Headers.new(
      "HTTP_CONTENT_TYPE" => "text/plain"
    )
  end

  test "content type" do
    assert_equal "text/plain", @headers["Content-Type"]
    assert_equal "text/plain", @headers["content-type"]
    assert_equal "text/plain", @headers["CONTENT_TYPE"]
    assert_equal "text/plain", @headers["HTTP_CONTENT_TYPE"]
  end
end
