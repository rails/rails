# frozen_string_literal: true

require "abstract_unit"

module OtherAfterTeardown
  def after_teardown
    @witness = true
  end
end

class AfterTeardownTest < Minitest::Test
  include OtherAfterTeardown
  include ActiveSupport::Testing::SetupAndTeardown

  attr_writer :witness

  MyError = Class.new(StandardError)

  teardown do
    raise MyError, "Test raises an error, all after_teardown should still get called"
  end

  def after_teardown
    assert_raises MyError do
      super
    end

    assert_equal true, @witness
  end

  def test_teardown_raise_but_all_after_teardown_method_are_called
    assert true
  end
end
