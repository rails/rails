# frozen_string_literal: true

require_relative "../abstract_unit"

module OtherTeardown
  def teardown
    super

    @witness = true
  end
end

class TeardownTest < ActiveSupport::TestCase
  include OtherTeardown

  attr_writer :witness

  MyError = Class.new(StandardError)

  teardown do
    raise MyError, "Test raises an error, all teardown should still get called"
  end

  def teardown
    assert_changes -> { failures.count }, from: 0, to: 1 do
      super
    end

    assert_equal true, @witness
    failures.clear
  end

  def test_teardown_raise_but_all_teardown_method_are_called
    assert true
  end
end
