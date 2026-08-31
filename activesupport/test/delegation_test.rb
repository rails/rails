# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/core_ext/module/delegation"

class DelegationTest < ActiveSupport::TestCase
  # A class whose methods yield to an implicit block (no explicit `&block`
  # parameter), plus a few other arities to guard against regressions.
  class Target
    def each_doubled
      yield 1
      yield 2
    end

    def maybe_yield
      yield :yielded if block_given?
      :returned
    end

    def with_required(arg)
      yield arg
    end

    def with_keyword(value:)
      yield value
    end
  end

  DelegatingWrapper = ActiveSupport::Delegation.DelegateClass(Target)

  setup do
    @wrapper = DelegatingWrapper.new(Target.new)
  end

  test "forwards a block to a delegated method that yields implicitly" do
    collected = []
    @wrapper.each_doubled { |value| collected << value }
    assert_equal [1, 2], collected
  end

  test "block_given? is true in the delegated method when a block is passed" do
    assert_equal :yielded, (@wrapper.maybe_yield { |v| break v })
  end

  test "no block is forwarded when none is given" do
    assert_equal :returned, @wrapper.maybe_yield
  end

  test "forwards a block alongside a required positional argument" do
    assert_equal 42, (@wrapper.with_required(42) { |arg| break arg })
  end

  test "forwards a block alongside a required keyword argument" do
    assert_equal :ok, (@wrapper.with_keyword(value: :ok) { |v| break v })
  end

  test "forwards a block to a yielding method inherited from the delegated class" do
    wrapper = ActiveSupport::Delegation.DelegateClass(Array).new([1, 2, 3])
    assert_equal [2, 4, 6], wrapper.map { |n| n * 2 }
    assert_equal [1, 3], wrapper.select(&:odd?)
  end
end
