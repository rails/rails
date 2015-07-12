require 'abstract_unit'
require 'active_support/testing/method_call_assertions'

class MethodCallAssertionsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions

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
      assert_called(@object, :increment, 'dang it') do
        # Call nothing...
      end
    end

    assert_match(/dang it.\nExpected increment/, error.message)
  end

  def test_assert_called_when_method_has_arguments
    assert_called @object, :<< do
      @object << 2
    end
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

  def test_assert_called_with_multiple_expected_arguments_and_shared_return
    returns = %i(a b c)
    assert_called_with(@object, :<<, [ [ 1 ], [ 2 ] ], returns: returns) do
      assert_equal(returns, @object << 1)
      assert_equal(returns, @object << 2)
    end
  end

  def test_assert_called_with_multiple_expected_arguments_and_distinct_returns
    assert_called_with(@object, :<<, [ [ 1 ], [ 2 ] ], returns: %i(a b), use_distinct_returns: true) do
      assert_equal(:a, @object << 1)
      assert_equal(:b, @object << 2)
    end
  end

  def test_assert_called_requires_the_returns_option_when_dealing_with_distinct_returns
    error = assert_raises(ArgumentError) do
      assert_called_with(@object, :<<, [], use_distinct_returns: true) do
        # Call nothing...
      end
    end
    assert_equal('returns must be an array and match the number of arguments', error.message)
  end

  def test_assert_called_requires_returns_to_be_an_array_when_dealing_with_distinct_returns
    error = assert_raises(ArgumentError) do
      assert_called_with(@object, :<<, [], returns: 1, use_distinct_returns: true) do
        # Call nothing...
      end
    end
    assert_equal('returns must be an array and match the number of arguments', error.message)
  end

  def test_assert_called_requires_returns_to_match_the_number_of_arguments_when_dealing_with_distinct_returns
    error = assert_raises(ArgumentError) do
      assert_called_with(@object, :<<, [ [ 1 ], [ 2 ] ], returns: %i(a b c), use_distinct_returns: true) do
        # Call nothing...
      end
    end
    assert_equal('returns must be an array and match the number of arguments', error.message)

    error = assert_raises(ArgumentError) do
      assert_called_with(@object, :<<, [ [ 1 ] ], returns: %i(a b), use_distinct_returns: true) do
        # Call nothing...
      end
    end
    assert_equal('returns must be an array and match the number of arguments', error.message)
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
end
