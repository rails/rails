# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/name_error"

class NameErrorTest < ActiveSupport::TestCase
  def test_name_error_should_set_missing_name
    exc = assert_raise NameError do
      SomeNameThatNobodyWillUse____Really ? 1 : 0
    end
    assert_equal "NameErrorTest::SomeNameThatNobodyWillUse____Really", exc.missing_name
    assert exc.missing_name?(:SomeNameThatNobodyWillUse____Really)
    assert exc.missing_name?("NameErrorTest::SomeNameThatNobodyWillUse____Really")
    assert_equal NameErrorTest, exc.receiver
  end

  def test_missing_method_should_ignore_missing_name
    exc = assert_raise NameError do
      some_method_that_does_not_exist
    end
    assert_not exc.missing_name?(:Foo)
    assert_nil exc.missing_name
    assert_equal self, exc.receiver
  end

  def test_missing_top_level_constant_is_not_namespaced
    exc = assert_raise NameError do
      ::SomeTopLevelNameThatNobodyWillUse____Really ? 1 : 0
    end
    assert_equal Object, exc.receiver
    assert_equal "SomeTopLevelNameThatNobodyWillUse____Really", exc.missing_name
    assert exc.missing_name?(:SomeTopLevelNameThatNobodyWillUse____Really)
    assert exc.missing_name?("SomeTopLevelNameThatNobodyWillUse____Really")
  end

  def test_missing_name_falls_back_to_the_message_without_a_receiver
    exc = NameError.new("uninitialized constant Foo::Bar")

    assert_raise(ArgumentError) { exc.receiver }
    assert_equal "Foo::Bar", exc.missing_name
    assert exc.missing_name?("Foo::Bar")
  end

  def test_missing_name_ignores_a_message_that_is_not_about_a_constant
    exc = NameError.new("undefined local variable or method 'foo'")

    assert_nil exc.missing_name
    assert_not exc.missing_name?("foo")
  end
end
