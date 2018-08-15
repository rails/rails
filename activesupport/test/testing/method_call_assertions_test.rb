# frozen_string_literal: true

require "abstract_unit"

class MethodCallAssertionsTest < ActiveSupport::TestCase
  class Level
    def increment; 1; end
    def decrement; end
    def <<(arg); end
  end

  setup do
    @object = Level.new
  end

  def test_assert_called_with_defaults_to_expect_once
    assert_called @object, :increment do
      @object.increment
    end
  end

  def test_assert_called_more_than_once
    assert_called(@object, :increment, times: 2) do
      @object.increment
      @object.increment
    end
  end

  def test_assert_called_method_with_arguments
    assert_called(@object, :<<) do
      @object << 2
    end
  end

  def test_assert_called_returns
    assert_called(@object, :increment, returns: 10) do
      assert_equal 10, @object.increment
    end

    assert_equal 1, @object.increment
  end

  def test_assert_called_failure
    error = assert_raises(Minitest::Assertion) do
      assert_called(@object, :increment) do
        # Call nothing...
      end
    end

    assert_equal "Expected increment to be called 1 times, but was called 0 times.\nExpected: 1\n  Actual: 0", error.message
  end

  def test_assert_called_with_message
    error = assert_raises(Minitest::Assertion) do
      assert_called(@object, :increment, "dang it") do
        # Call nothing...
      end
    end

    assert_match(/dang it.\nExpected increment/, error.message)
  end

  def test_assert_called_with
    assert_called_with(@object, :increment) do
      @object.increment
    end
  end

  def test_assert_called_with_arguments
    assert_called_with(@object, :<<, [ 2 ]) do
      @object << 2
    end
  end

  def test_assert_called_with_arguments_and_returns
    assert_called_with(@object, :<<, [ 2 ], returns: 10) do
      assert_equal(10, @object << 2)
    end

    assert_nil(@object << 2)
  end

  def test_assert_called_with_failure
    assert_raises(MockExpectationError) do
      assert_called_with(@object, :<<, [ 4567 ]) do
        @object << 2
      end
    end
  end

  def test_assert_called_with_returns
    assert_called_with(@object, :increment, returns: 1) do
      @object.increment
    end
  end

  def test_assert_called_with_multiple_expected_arguments
    assert_called_with(@object, :<<, [ [ 1 ], [ 2 ] ]) do
      @object << 1
      @object << 2
    end
  end

  def test_assert_not_called
    assert_not_called(@object, :decrement) do
      @object.increment
    end
  end

  def test_assert_not_called_failure
    error = assert_raises(Minitest::Assertion) do
      assert_not_called(@object, :increment) do
        @object.increment
      end
    end

    assert_equal "Expected increment to be called 0 times, but was called 1 times.\nExpected: 0\n  Actual: 1", error.message
  end

  def test_stub_any_instance
    stub_any_instance(Level) do |instance|
      assert_equal instance, Level.new
    end
  end

  def test_stub_any_instance_with_instance
    stub_any_instance(Level, instance: @object) do |instance|
      assert_equal @object, instance
      assert_equal instance, Level.new
    end
  end
end
