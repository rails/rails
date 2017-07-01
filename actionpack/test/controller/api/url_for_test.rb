require "abstract_unit"

class UrlForApiController < ActionController::API
  def one; end
  def two; end
end

class UrlForApiTest < ActionController::TestCase
  tests UrlForApiController

  def setup
    super
    @request.host = "www.example.com"
  end

  def test_url_for
    get :one
    assert_equal "http://www.example.com/url_for_api/one", @controller.url_for
  end
end
