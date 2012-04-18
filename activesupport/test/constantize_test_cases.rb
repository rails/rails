module Ace
  module Base
    class Case
    end
  end
end

module ConstantizeTestCases
  def run_constantize_tests_on
    assert_nothing_raised { assert_equal Ace::Base::Case, yield("Ace::Base::Case") }
    assert_nothing_raised { assert_equal Ace::Base::Case, yield("::Ace::Base::Case") }
    assert_nothing_raised { assert_equal ConstantizeTestCases, yield("ConstantizeTestCases") }
    assert_nothing_raised { assert_equal ConstantizeTestCases, yield("::ConstantizeTestCases") }
    assert_raise(NameError) { yield("UnknownClass") }
    assert_raise(NameError) { yield("UnknownClass::Ace") }
    assert_raise(NameError) { yield("UnknownClass::Ace::Base") }
    assert_raise(NameError) { yield("An invalid string") }
    assert_raise(NameError) { yield("InvalidClass\n") }
    assert_raise(NameError) { yield("Ace::ConstantizeTestCases") }
    assert_raise(NameError) { yield("Ace::Base::ConstantizeTestCases") }
  end

  def run_safe_constantize_tests_on
    assert_nothing_raised { assert_equal Ace::Base::Case, yield("Ace::Base::Case") }
    assert_nothing_raised { assert_equal Ace::Base::Case, yield("::Ace::Base::Case") }
    assert_nothing_raised { assert_equal ConstantizeTestCases, yield("ConstantizeTestCases") }
    assert_nothing_raised { assert_equal ConstantizeTestCases, yield("::ConstantizeTestCases") }
    assert_nothing_raised { assert_equal nil, yield("UnknownClass") }
    assert_nothing_raised { assert_equal nil, yield("UnknownClass::Ace") }
    assert_nothing_raised { assert_equal nil, yield("UnknownClass::Ace::Base") }
    assert_nothing_raised { assert_equal nil, yield("An invalid string") }
    assert_nothing_raised { assert_equal nil, yield("InvalidClass\n") }
    assert_nothing_raised { assert_equal nil, yield("blargle") }
    assert_nothing_raised { assert_equal nil, yield("Ace::ConstantizeTestCases") }
    assert_nothing_raised { assert_equal nil, yield("Ace::Base::ConstantizeTestCases") }
    assert_nothing_raised { assert_equal nil, yield("#<Class:0x7b8b718b>::Nested_1") }
  end
end
