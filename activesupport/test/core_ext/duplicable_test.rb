require 'abstract_unit'
require 'bigdecimal'
require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/numeric/time'

class DuplicableTest < ActiveSupport::TestCase
  RAISE_DUP  = [nil, false, true, :symbol, 1, 2.3, BigDecimal.new('4.56'), 5.seconds]
  YES = ['1', Object.new, /foo/, [], {}, Time.now]
  NO = [Class.new, Module.new]

  def test_duplicable
    (RAISE_DUP + NO).each do |v|
      assert !v.duplicable?
    end

    YES.each do |v|
      assert v.duplicable?
    end

    (YES + NO).each do |v|
      assert_nothing_raised { v.dup }
    end

    RAISE_DUP.each do |v|
      assert_raises(TypeError, v.class.name) do
        v.dup
      end
    end
  end
end
