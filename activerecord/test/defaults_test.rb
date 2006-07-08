require 'abstract_unit'
require 'fixtures/default'

if current_adapter?(:PostgreSQLAdapter, :SQLServerAdapter)
  class DefaultsTest < Test::Unit::TestCase
    def test_default_integers
      default = Default.new
      assert_instance_of Fixnum, default.positive_integer
      assert_equal 1, default.positive_integer
      assert_instance_of Fixnum, default.negative_integer
      assert_equal -1, default.negative_integer
      assert_instance_of BigDecimal, default.decimal_number
      assert_equal BigDecimal.new("2.78"), default.decimal_number
    end
  end
end
