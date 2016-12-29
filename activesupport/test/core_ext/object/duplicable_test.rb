require "abstract_unit"
require "bigdecimal"
require "active_support/core_ext/object/duplicable"
require "active_support/core_ext/numeric/time"

class DuplicableTest < ActiveSupport::TestCase
  if RUBY_VERSION >= "2.4.0"
    RAISE_DUP = [method(:puts), Complex(1), Rational(1)]
    ALLOW_DUP = ["1", Object.new, /foo/, [], {}, Time.now, Class.new, Module.new, BigDecimal.new("4.56"), nil, false, true, :symbol, 1, 2.3]
  else
    RAISE_DUP = [nil, false, true, :symbol, 1, 2.3, method(:puts), Complex(1), Rational(1)]
    ALLOW_DUP = ["1", Object.new, /foo/, [], {}, Time.now, Class.new, Module.new, BigDecimal.new("4.56")]
  end

  def test_duplicable
    rubinius_skip "* Method#dup is allowed at the moment on Rubinius\n" \
                  "* https://github.com/rubinius/rubinius/issues/3089"

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
