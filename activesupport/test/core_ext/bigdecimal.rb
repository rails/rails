require 'abstract_unit'

class BigDecimalTest < Test::Unit::TestCase
  def test_to_yaml
    assert_equal("--- 100000.30020320320000000000000000000000000000001\n", BigDecimal.new('100000.30020320320000000000000000000000000000001').to_yaml)
    assert_equal("--- .Inf\n", BigDecimal.new('Infinity').to_yaml)
    assert_equal("--- .NaN\n", BigDecimal.new('NaN').to_yaml)
    assert_equal("--- -.Inf\n", BigDecimal.new('-Infinity').to_yaml)
  end
end