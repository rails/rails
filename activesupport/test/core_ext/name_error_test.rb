# frozen_string_literal: true

require_relative '../abstract_unit'
require 'active_support/core_ext/name_error'

class NameErrorTest < ActiveSupport::TestCase
  def test_name_error_should_set_missing_name
    exc = assert_raise NameError do
      SomeNameThatNobodyWillUse____Really ? 1 : 0
    end
    assert_equal 'NameErrorTest::SomeNameThatNobodyWillUse____Really', exc.missing_name
    assert exc.missing_name?(:SomeNameThatNobodyWillUse____Really)
    assert exc.missing_name?('NameErrorTest::SomeNameThatNobodyWillUse____Really')
    if RUBY_VERSION >= '2.6'
      assert_equal NameErrorTest, exc.receiver
    end
  end

  def test_missing_method_should_ignore_missing_name
    exc = assert_raise NameError do
      some_method_that_does_not_exist
    end
    assert_not exc.missing_name?(:Foo)
    assert_nil exc.missing_name
    assert_equal self, exc.receiver
  end
end
