require 'abstract_unit'
require 'active_support/core_ext/regexp'

class RegexpExtAccessTests < ActiveSupport::TestCase
  def test_multiline
    assert_equal true, //m.multiline?
    assert_equal false, //.multiline?
    assert_equal false, /(?m:)/.multiline?
  end
end
