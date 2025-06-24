# frozen_string_literal: true

require_relative "../abstract_unit"

class AfterTeardownAssertionTest < ActiveSupport::TestCase
  module OtherAfterTeardown
    def after_teardown
      super

      @witness = true
    end
  end
  include AfterTeardownAssertionTest::OtherAfterTeardown

  attr_writer :witness

  teardown do
    flunk "Test raises a Minitest::Assertion error, all after_teardown should still get called"
  end

  def after_teardown
    assert_changes -> { failures.count }, from: 0, to: 1 do
      super
    end

    assert_equal true, @witness
    failures.clear
  end

  def test_teardown_raise_but_all_after_teardown_method_are_called
    assert true
  end
end
