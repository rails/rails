require File.dirname(__FILE__) + '/../abstract_unit'

class NameErrorTest < Test::Unit::TestCase
  def test_name_error_should_set_missing_name
    begin
      SomeNameThatNobodyWillUse____Really ? 1 : 0
      flunk "?!?!"
    rescue NameError => exc
      assert_equal "NameErrorTest::SomeNameThatNobodyWillUse____Really", exc.missing_name
      assert exc.missing_name?(:SomeNameThatNobodyWillUse____Really)
      assert exc.missing_name?("NameErrorTest::SomeNameThatNobodyWillUse____Really")
    end
  end

  def test_missing_method_should_ignore_missing_name
    begin
      some_method_that_does_not_exist
      flunk "?!?!"
    rescue NameError => exc
      assert_equal nil, exc.missing_name
      assert ! exc.missing_name?(:Foo)
    end
  end
end
