require 'abstract_unit'
require 'active_support/core_ext/big_decimal'

class BigDecimalTest < ActiveSupport::TestCase
  def test_to_s
    bd = BigDecimal.new '0.01'
    assert_equal '0.01', bd.to_s
    assert_equal '+0.01', bd.to_s('+F')
    assert_equal '+0.0 1', bd.to_s('+1F')
  end
end
