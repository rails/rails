require 'abstract_unit'
require 'bigdecimal'
require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/numeric/time'

class DuplicableTest < ActiveSupport::TestCase
  if RUBY_VERSION >= "2.4.1"
    RAISE_DUP = [method(:puts)]
    ALLOW_DUP = ["1", 'symbol_from_string'.to_sym, Object.new, /foo/, [], {}, Time.now, Class.new, Module.new, BigDecimal.new("4.56"), nil, false, true, 1, 2.3]
  elsif RUBY_VERSION >= "2.4.0"  # Due to 2.4.0 bug. This elsif cannot be removed unless we drop 2.4.0 support...
    RAISE_DUP = [method(:puts), 'symbol_from_string'.to_sym]
    ALLOW_DUP = ["1", Object.new, /foo/, [], {}, Time.now, Class.new, Module.new, BigDecimal.new("4.56"), nil, false, true, 1, 2.3]
  else
    RAISE_DUP = [nil, false, true, :symbol, 1, 2.3, method(:puts)]
    ALLOW_DUP = ["1", Object.new, /foo/, [], {}, Time.now, Class.new, Module.new]

    # Needed to support Ruby 1.9.x, as it doesn't allow dup on BigDecimal, instead
    # raises TypeError exception. Checking here on the runtime whether BigDecimal
    # will allow dup or not.
    begin
      bd = BigDecimal.new('4.56')
      ALLOW_DUP << bd.dup
    rescue TypeError
      RAISE_DUP << bd
    end
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
