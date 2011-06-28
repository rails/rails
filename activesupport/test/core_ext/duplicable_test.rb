require 'abstract_unit'
require 'bigdecimal'
require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/numeric/time'

class DuplicableTest < Test::Unit::TestCase
  NO  = [nil, false, true, :symbol, 1, 2.3, BigDecimal.new('4.56'), Class.new, Module.new, 5.seconds]
  YES = ['1', Object.new, /foo/, [], {}, Time.now]

  def test_duplicable
    NO.each do |v|
      assert !v.duplicable?
      begin
        v.dup
        fail
      rescue Exception
      end
    end

    YES.each do |v|
      assert v.duplicable?
      assert_nothing_raised { v.dup }
    end
  end
end
