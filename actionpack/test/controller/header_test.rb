require 'abstract_unit'

class HeaderTest < Test::Unit::TestCase
  def setup
    @headers = ActionController::Http::Headers.new("HTTP_CONTENT_TYPE"=>"text/plain")
  end
  
  def test_content_type_works
    assert_equal "text/plain", @headers["Content-Type"]
    assert_equal "text/plain", @headers["content-type"]
    assert_equal "text/plain", @headers["CONTENT_TYPE"]
    assert_equal "text/plain", @headers["HTTP_CONTENT_TYPE"]    
  end
end
