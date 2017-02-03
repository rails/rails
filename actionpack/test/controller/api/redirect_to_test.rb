require "abstract_unit"

class RedirectToApiController < ActionController::API
  def one
    redirect_to action: "two"
  end

  def two; end
end

class RedirectToApiTest < ActionController::TestCase
  tests RedirectToApiController

  def test_redirect_to
    get :one
    assert_response :redirect
    assert_equal "http://test.host/redirect_to_api/two", redirect_to_url
  end
end
