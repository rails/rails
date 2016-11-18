require "dependencies_test_helpers"

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
  include DependenciesTestHelpers

  def run_constantize_tests_on
    assert_equal Ace::Base::Case, yield("Ace::Base::Case")
    assert_equal Ace::Base::Case, yield("::Ace::Base::Case")
    assert_equal Ace::Base::Case::Dice, yield("Ace::Base::Case::Dice")
    assert_equal Ace::Base::Case::Dice, yield("Ace::Base::Fase::Dice")
    assert_equal Ace::Base::Fase::Dice, yield("Ace::Base::Fase::Dice")

    assert_equal Ace::Gas::Case, yield("Ace::Gas::Case")
    assert_equal Ace::Gas::Case::Dice, yield("Ace::Gas::Case::Dice")
    assert_equal Ace::Base::Case::Dice, yield("Ace::Gas::Case::Dice")

    assert_equal Case::Dice, yield("Case::Dice")
    assert_equal AddtlGlobalConstants::Case::Dice, yield("Case::Dice")
    assert_equal Object::AddtlGlobalConstants::Case::Dice, yield("Case::Dice")

    assert_equal Case::Dice, yield("Object::Case::Dice")
    assert_equal AddtlGlobalConstants::Case::Dice, yield("Object::Case::Dice")
    assert_equal Object::AddtlGlobalConstants::Case::Dice, yield("Case::Dice")

    assert_equal ConstantizeTestCases, yield("ConstantizeTestCases")
    assert_equal ConstantizeTestCases, yield("::ConstantizeTestCases")

    assert_raises(NameError) { yield("UnknownClass") }
    assert_raises(NameError) { yield("UnknownClass::Ace") }
    assert_raises(NameError) { yield("UnknownClass::Ace::Base") }
    assert_raises(NameError) { yield("An invalid string") }
    assert_raises(NameError) { yield("InvalidClass\n") }
    assert_raises(NameError) { yield("Ace::ConstantizeTestCases") }
    assert_raises(NameError) { yield("Ace::Base::ConstantizeTestCases") }
    assert_raises(NameError) { yield("Ace::Gas::Base") }
    assert_raises(NameError) { yield("Ace::Gas::ConstantizeTestCases") }
    assert_raises(NameError) { yield("") }
    assert_raises(NameError) { yield("::") }
    assert_raises(NameError) { yield("Ace::gas") }

    assert_raises(NameError) do
      with_autoloading_fixtures do
        yield("RaisesNameError")
      end
    end

    assert_raises(NoMethodError) do
      with_autoloading_fixtures do
        yield("RaisesNoMethodError")
      end
    end
  end

  def run_safe_constantize_tests_on
    assert_equal Ace::Base::Case, yield("Ace::Base::Case")
    assert_equal Ace::Base::Case, yield("::Ace::Base::Case")
    assert_equal Ace::Base::Case::Dice, yield("Ace::Base::Case::Dice")
    assert_equal Ace::Base::Fase::Dice, yield("Ace::Base::Fase::Dice")
    assert_equal Ace::Gas::Case, yield("Ace::Gas::Case")
    assert_equal Ace::Gas::Case::Dice, yield("Ace::Gas::Case::Dice")
    assert_equal Case::Dice, yield("Case::Dice")
    assert_equal Case::Dice, yield("Object::Case::Dice")
    assert_equal ConstantizeTestCases, yield("ConstantizeTestCases")
    assert_equal ConstantizeTestCases, yield("::ConstantizeTestCases")
    assert_nil yield("")
    assert_nil yield("::")
    assert_nil yield("UnknownClass")
    assert_nil yield("UnknownClass::Ace")
    assert_nil yield("UnknownClass::Ace::Base")
    assert_nil yield("An invalid string")
    assert_nil yield("InvalidClass\n")
    assert_nil yield("blargle")
    assert_nil yield("Ace::ConstantizeTestCases")
    assert_nil yield("Ace::Base::ConstantizeTestCases")
    assert_nil yield("Ace::Gas::Base")
    assert_nil yield("Ace::Gas::ConstantizeTestCases")
    assert_nil yield("#<Class:0x7b8b718b>::Nested_1")
    assert_nil yield("Ace::gas")
    assert_nil yield("Object::ABC")
    assert_nil yield("Object::Object::Object::ABC")
    assert_nil yield("A::Object::B")
    assert_nil yield("A::Object::Object::Object::B")

    assert_raises(NameError) do
      with_autoloading_fixtures do
        yield("RaisesNameError")
      end
    end

    assert_raises(NoMethodError) do
      with_autoloading_fixtures do
        yield("RaisesNoMethodError")
      end
    end
  end
end
