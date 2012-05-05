module Ace
  module Base
    class Case
      class Dice
      end
    end
    class Fase < Case
    end
  end
  class Gas
    include Base
  end
end

class Object
  module AddtlGlobalConstants
    class Case
      class Dice
      end
    end
  end
  include AddtlGlobalConstants
end

module ConstantizeTestCases
  def run_constantize_tests_on
    assert_nothing_raised { assert_equal Ace::Base::Case, yield("Ace::Base::Case") }
    assert_nothing_raised { assert_equal Ace::Base::Case, yield("::Ace::Base::Case") }
    assert_nothing_raised { assert_equal Ace::Base::Case::Dice, yield("Ace::Base::Case::Dice") }
    assert_nothing_raised { assert_equal Ace::Base::Fase::Dice, yield("Ace::Base::Fase::Dice") }
    assert_nothing_raised { assert_equal Ace::Gas::Case, yield("Ace::Gas::Case") }
    assert_nothing_raised { assert_equal Case::Dice, yield("Case::Dice") }
    assert_nothing_raised { assert_equal Case::Dice, yield("Object::Case::Dice") }
    assert_nothing_raised { assert_equal ConstantizeTestCases, yield("ConstantizeTestCases") }
    assert_nothing_raised { assert_equal ConstantizeTestCases, yield("::ConstantizeTestCases") }
    assert_nothing_raised { assert_equal Object, yield("") }
    assert_nothing_raised { assert_equal Object, yield("::") }
    assert_raise(NameError) { yield("UnknownClass") }
    assert_raise(NameError) { yield("UnknownClass::Ace") }
    assert_raise(NameError) { yield("UnknownClass::Ace::Base") }
    assert_raise(NameError) { yield("An invalid string") }
    assert_raise(NameError) { yield("InvalidClass\n") }
    assert_raise(NameError) { yield("Ace::ConstantizeTestCases") }
    assert_raise(NameError) { yield("Ace::Base::ConstantizeTestCases") }
    assert_raise(NameError) { yield("Ace::Gas::Base") }
    assert_raise(NameError) { yield("Ace::Gas::ConstantizeTestCases") }
  end

  def run_safe_constantize_tests_on
    assert_nothing_raised { assert_equal Ace::Base::Case, yield("Ace::Base::Case") }
    assert_nothing_raised { assert_equal Ace::Base::Case, yield("::Ace::Base::Case") }
    assert_nothing_raised { assert_equal Ace::Base::Case::Dice, yield("Ace::Base::Case::Dice") }
    assert_nothing_raised { assert_equal Ace::Base::Fase::Dice, yield("Ace::Base::Fase::Dice") }
    assert_nothing_raised { assert_equal Ace::Gas::Case, yield("Ace::Gas::Case") }
    assert_nothing_raised { assert_equal Case::Dice, yield("Case::Dice") }
    assert_nothing_raised { assert_equal Case::Dice, yield("Object::Case::Dice") }
    assert_nothing_raised { assert_equal ConstantizeTestCases, yield("ConstantizeTestCases") }
    assert_nothing_raised { assert_equal ConstantizeTestCases, yield("::ConstantizeTestCases") }
    assert_nothing_raised { assert_equal Object, yield("") }
    assert_nothing_raised { assert_equal Object, yield("::") }
    assert_nothing_raised { assert_equal nil, yield("UnknownClass") }
    assert_nothing_raised { assert_equal nil, yield("UnknownClass::Ace") }
    assert_nothing_raised { assert_equal nil, yield("UnknownClass::Ace::Base") }
    assert_nothing_raised { assert_equal nil, yield("An invalid string") }
    assert_nothing_raised { assert_equal nil, yield("InvalidClass\n") }
    assert_nothing_raised { assert_equal nil, yield("blargle") }
    assert_nothing_raised { assert_equal nil, yield("Ace::ConstantizeTestCases") }
    assert_nothing_raised { assert_equal nil, yield("Ace::Base::ConstantizeTestCases") }
    assert_nothing_raised { assert_equal nil, yield("Ace::Gas::Base") }
    assert_nothing_raised { assert_equal nil, yield("Ace::Gas::ConstantizeTestCases") }
    assert_nothing_raised { assert_equal nil, yield("#<Class:0x7b8b718b>::Nested_1") }
  end
end
