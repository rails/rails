require 'abstract_unit'
require 'bigdecimal'
require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/numeric/time'

class DuplicableTest < ActiveSupport::TestCase
  RAISE_DUP  = [nil, false, true, :symbol, 1, 2.3, 5.seconds]
  ALLOW_DUP = ['1', Object.new, /foo/, [], {}, Time.now, Class.new, Module.new]

  # Needed to support Ruby 1.9.x, as it doesn't allow dup on BigDecimal, instead
  # raises TypeError exception. Checking here on the runtime whether BigDecimal
  # will allow dup or not.
  begin
    bd = BigDecimal.new('4.56')
    ALLOW_DUP << bd.dup
  rescue TypeError
    RAISE_DUP << bd
  end

  def test_duplicable
    RAISE_DUP.each do |v|
      assert !v.duplicable?
      assert_raises(TypeError, v.class.name) { v.dup }
    end

    ALLOW_DUP.each do |v|
      assert v.duplicable?, "#{ v.class } should be duplicable"
      assert_nothing_raised { v.dup }
    end
  end
end
