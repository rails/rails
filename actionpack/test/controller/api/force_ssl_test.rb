# frozen_string_literal: true

require "abstract_unit"

class ForceSSLApiController < ActionController::API
  ActiveSupport::Deprecation.silence do
    force_ssl
  end

  def one; end
  def two
    head :ok
  end
end

class ForceSSLApiTest < ActionController::TestCase
  tests ForceSSLApiController

  def test_redirects_to_https
    get :two
    assert_response 301
    assert_equal "https://test.host/force_ssl_api/two", redirect_to_url
  end
end
