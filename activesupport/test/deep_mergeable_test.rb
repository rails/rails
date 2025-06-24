# frozen_string_literal: true

require_relative "abstract_unit"

class DeepMergeableTest < ActiveSupport::TestCase
  Wrapper = Struct.new(:underlying) do
    include ActiveSupport::DeepMergeable

    class << self
      remove_method :[]

      def [](value)
        if value.is_a?(Hash)
          self.new(value.transform_values { |value| self[value] })
        else
          value
        end
      end
    end

    delegate :[], to: :underlying

    def merge!(other, &block)
      self.underlying = underlying.merge(other.underlying, &block)
      self
    end
  end

  SubWrapper = Class.new(Wrapper)

  OtherWrapper = Wrapper.dup

  OmniWrapper = Class.new(Wrapper) do
    def deep_merge?(other)
      super || other.is_a?(OtherWrapper)
    end
  end

  setup do
    @hash_1 = { a: 1, b: 1, c: { d1: 1, d2: 1, d3: { e1: 1,        e3: 1 } } }
    @hash_2 = { a: 2,       c: {        d2: 2, d3: {        e2: 2, e3: 2 } } }
    @merged = { a: 2, b: 1, c: { d1: 1, d2: 2, d3: { e1: 1, e2: 2, e3: 2 } } }
    @summed = { a: 3, b: 1, c: { d1: 1, d2: 3, d3: { e1: 1, e2: 2, e3: 3 } } }

    @nested_value_key = :c
    @sum_values = -> (key, value_1, value_2) { value_1 + value_2 }
  end

  test "deep_merge works" do
    assert_equal Wrapper[@merged], Wrapper[@hash_1].deep_merge(Wrapper[@hash_2])
  end

  test "deep_merge! works" do
    assert_equal Wrapper[@merged], Wrapper[@hash_1].deep_merge!(Wrapper[@hash_2])
  end

  test "deep_merge supports a merge block" do
    assert_equal Wrapper[@summed], Wrapper[@hash_1].deep_merge(Wrapper[@hash_2], &@sum_values)
  end

  test "deep_merge! supports a merge block" do
    assert_equal Wrapper[@summed], Wrapper[@hash_1].deep_merge!(Wrapper[@hash_2], &@sum_values)
  end

  test "deep_merge does not mutate the instance" do
    instance = Wrapper[@hash_1.dup]
    instance.deep_merge(Wrapper[@hash_2])
    assert_equal Wrapper[@hash_1], instance
  end

  test "deep_merge! mutates the instance" do
    instance = Wrapper[@hash_1]
    instance.deep_merge!(Wrapper[@hash_2])
    assert_equal Wrapper[@merged], instance
  end

  test "deep_merge! does not mutate the underlying values" do
    instance = Wrapper[@hash_1.dup]
    underlying = instance.underlying
    instance.deep_merge!(Wrapper[@hash_2])
    assert_equal Wrapper[@hash_1].underlying, underlying
  end

  test "deep_merge deep merges subclass values by default" do
    nested_value = Wrapper[@hash_1].deep_merge(SubWrapper[@hash_2])[@nested_value_key]
    assert_equal Wrapper[@merged][@nested_value_key], nested_value
  end

  test "deep_merge does not deep merge non-subclass values by default" do
    nested_value = Wrapper[@hash_1].deep_merge(OtherWrapper[@hash_2])[@nested_value_key]
    assert_equal OtherWrapper[@hash_2][@nested_value_key], nested_value
  end

  test "deep_merge? can be overridden to allow deep merging of non-subclass values" do
    nested_value = OmniWrapper[@hash_1].deep_merge(OtherWrapper[@hash_2])[@nested_value_key]
    assert_equal OmniWrapper[@merged][@nested_value_key], nested_value
  end
end
