require 'abstract_unit'

class RedirectToHTTPController < ActionController::HTTP
  def one
    redirect_to :action => "two"
  end

  def two; end
end

class RedirectToHTTPTest < ActionController::TestCase
  tests RedirectToHTTPController

  def test_redirect_to
    get :one
    assert_response :redirect
    assert_equal "http://test.host/redirect_to_http/two", redirect_to_url
  end
end
