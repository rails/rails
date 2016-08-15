require "abstract_unit"
require "bigdecimal"
require "active_support/core_ext/object/duplicable"
require "active_support/core_ext/numeric/time"

class DuplicableTest < ActiveSupport::TestCase
  RAISE_DUP  = [nil, false, true, :symbol, 1, 2.3, method(:puts)]
  ALLOW_DUP = ["1", Object.new, /foo/, [], {}, Time.now, Class.new, Module.new]
  ALLOW_DUP << BigDecimal.new("4.56")

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
