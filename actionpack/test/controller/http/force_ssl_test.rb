require 'abstract_unit'

class ForceSSLHTTPController < ActionController::HTTP
  force_ssl

  def one; end
  def two
    head :ok
  end
end

class ForceSSLHTTPTest < ActionController::TestCase
  tests ForceSSLHTTPController

  def test_banana_redirects_to_https
    get :two
    assert_response 301
    assert_equal "https://test.host/force_sslhttp/two", redirect_to_url
  end
end
