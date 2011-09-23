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
    assert_raise(NameError) { yield("An invalid string") }
    assert_raise(NameError) { yield("InvalidClass\n") }
    assert_raise(NameError) { yield("Ace::Base::ConstantizeTestCases") }
    
    # any NameError it raises should have name set to the full specified String (not just part of it)
    begin
      yield("Ace::Base::Blargle")
      assert false
    rescue NameError => e
      assert_equal "Ace::Base::Blargle", e.name
    end
  end
  
  def run_safe_constantize_tests_on
    assert_nothing_raised { assert_equal Ace::Base::Case, yield("Ace::Base::Case") }
    assert_nothing_raised { assert_equal Ace::Base::Case, yield("::Ace::Base::Case") }
    assert_nothing_raised { assert_equal ConstantizeTestCases, yield("ConstantizeTestCases") }
    assert_nothing_raised { assert_equal ConstantizeTestCases, yield("::ConstantizeTestCases") }
    assert_nothing_raised { assert_equal nil, yield("UnknownClass") }
    assert_nothing_raised { assert_equal nil, yield("An invalid string") }
    assert_nothing_raised { assert_equal nil, yield("InvalidClass\n") }
    assert_nothing_raised { assert_equal nil, yield("blargle") }
    assert_nothing_raised { assert_equal nil, yield("Ace::Base::ConstantizeTestCases") }
    
    # should re-raise any NameError it encounters that doesn't correspond to the specified String
    NameError.any_instance.stubs(:name).returns("not-blargle")
    begin
      yield("blargle")
      assert false
    rescue NameError => e
      assert_equal "not-blargle", e.name
    end
  end
end