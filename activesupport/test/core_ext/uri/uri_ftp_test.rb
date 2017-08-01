# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/uri/ftp"

class URIFTPTest < ActiveSupport::TestCase
  def test_respond_to_add_params
    assert_respond_to URI("ftp://user:pass@host.com/abc/def"), :add_params
  end
end
