# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/uri/http"
require "active_support/core_ext/uri/utils/query_param"

class URIAddQueryParamTest < ActiveSupport::TestCase
  def test_uri_add_params
    uri = URI("http://www.test.com/")
    params = { a: "b", "c" => "d" }

    uri.add_params(params)
    assert_equal "http://www.test.com/?a=b&c=d", uri.to_s
  end

  def test_uri_add_params_with_query_parameters
    uri = URI("http://www.test.com?a=b")
    params = { c: "d" }

    uri.add_params(params)
    assert_equal "http://www.test.com?a=b&c=d", uri.to_s
  end

  def test_uri_add_params_collision
    uri = URI("http://www.test.com?a=b&c=d")
    params = { a: "b" }

    uri.add_params(params)
    assert_equal "http://www.test.com?a=b&c=d", uri.to_s
  end
end
