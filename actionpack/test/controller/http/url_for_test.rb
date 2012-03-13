require 'abstract_unit'

class UrlForHTTPController < ActionController::HTTP
  def one; end
  def two; end
end

class UrlForHTTPTest < ActionController::TestCase
  tests UrlForHTTPController

  def setup
    super
    @request.host = 'www.example.com'
  end

  def test_url_for
    get :one
    assert_equal "http://www.example.com/url_for_http/one", @controller.url_for
  end
end
