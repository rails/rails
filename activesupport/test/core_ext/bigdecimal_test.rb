require 'abstract_unit'
require 'bigdecimal'
require 'active_support/core_ext/big_decimal'

class BigDecimalTest < ActiveSupport::TestCase
  def test_to_yaml
    assert_match("--- 100000.30020320320000000000000000000000000000001\n", BigDecimal.new('100000.30020320320000000000000000000000000000001').to_yaml)
    assert_match("--- .Inf\n",  BigDecimal.new('Infinity').to_yaml)
    assert_match("--- .NaN\n",  BigDecimal.new('NaN').to_yaml)
    assert_match("--- -.Inf\n", BigDecimal.new('-Infinity').to_yaml)
  end

  def test_to_d
    bd = BigDecimal.new '10'
    assert_equal bd, bd.to_d
  end
  
  def test_to_s
    bd = BigDecimal.new '0.01'
    assert_equal '0.01', bd.to_s
  end
end
