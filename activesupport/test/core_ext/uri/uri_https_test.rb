# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/uri/http"

class URIHTTPSTest < ActiveSupport::TestCase
  def test_respond_to_add_params
    assert_respond_to URI("https://www.example.com"), :add_params
  end
end
