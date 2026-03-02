# frozen_string_literal: true

require_relative "abstract_unit"

class IsolatedExecutionStateTest < ActiveSupport::TestCase
  setup do
    ActiveSupport::IsolatedExecutionState.clear
    @original_isolation_level = ActiveSupport::IsolatedExecutionState.isolation_level
  end

  teardown do
    ActiveSupport::IsolatedExecutionState.clear
    ActiveSupport::IsolatedExecutionState.isolation_level = @original_isolation_level
  end

  test "#[] when isolation level is :fiber" do
    ActiveSupport::IsolatedExecutionState.isolation_level = :fiber

    ActiveSupport::IsolatedExecutionState[:test] = 42
    assert_equal 42, ActiveSupport::IsolatedExecutionState[:test]
    enumerator = Enumerator.new do |yielder|
      yielder.yield ActiveSupport::IsolatedExecutionState[:test]
    end
    assert_nil enumerator.next

    assert_nil Thread.new { ActiveSupport::IsolatedExecutionState[:test] }.value
  end

  test "#[] when isolation level is :thread" do
    ActiveSupport::IsolatedExecutionState.isolation_level = :thread

    ActiveSupport::IsolatedExecutionState[:test] = 42
    assert_equal 42, ActiveSupport::IsolatedExecutionState[:test]
    enumerator = Enumerator.new do |yielder|
      yielder.yield ActiveSupport::IsolatedExecutionState[:test]
    end
    assert_equal 42, enumerator.next

    assert_nil Thread.new { ActiveSupport::IsolatedExecutionState[:test] }.value
  end

  test "changing the isolation level clear the old store" do
    original = ActiveSupport::IsolatedExecutionState.isolation_level
    other = ActiveSupport::IsolatedExecutionState.isolation_level == :fiber ? :thread : :fiber

    ActiveSupport::IsolatedExecutionState[:test] = 42
    ActiveSupport::IsolatedExecutionState.isolation_level = original
    assert_equal 42, ActiveSupport::IsolatedExecutionState[:test]

    ActiveSupport::IsolatedExecutionState.isolation_level = other
    assert_nil ActiveSupport::IsolatedExecutionState[:test]

    ActiveSupport::IsolatedExecutionState.isolation_level = original
    assert_nil ActiveSupport::IsolatedExecutionState[:test]
  end

  test "#share_with copies state from another thread" do
    ActiveSupport::IsolatedExecutionState[:foo] = "bar"
    ActiveSupport::IsolatedExecutionState[:baz] = "qux"

    t1 = Thread.current
    result = nil

    Thread.new do
      ActiveSupport::IsolatedExecutionState.share_with(t1) do
        result = {
          foo: ActiveSupport::IsolatedExecutionState[:foo],
          baz: ActiveSupport::IsolatedExecutionState[:baz]
        }
      end
    end.join

    assert_equal "bar", result[:foo]
    assert_equal "qux", result[:baz]
  end

  test "#share_with restores original state after block" do
    ActiveSupport::IsolatedExecutionState[:original] = "value"

    t1 = Thread.current
    ActiveSupport::IsolatedExecutionState[:foo] = "parent"

    Thread.new do
      ActiveSupport::IsolatedExecutionState[:foo] = "child"
      ActiveSupport::IsolatedExecutionState[:bar] = "child_only"

      ActiveSupport::IsolatedExecutionState.share_with(t1) do
        assert_equal "parent", ActiveSupport::IsolatedExecutionState[:foo]
        assert_nil ActiveSupport::IsolatedExecutionState[:bar]
      end

      # After block, child thread should have its original state back
      assert_equal "child", ActiveSupport::IsolatedExecutionState[:foo]
      assert_equal "child_only", ActiveSupport::IsolatedExecutionState[:bar]
    end.join
  end

  test "#share_with with except parameter accepts single key or array" do
    ActiveSupport::IsolatedExecutionState[:foo] = "bar"
    ActiveSupport::IsolatedExecutionState[:secret1] = "should not copy"
    ActiveSupport::IsolatedExecutionState[:secret2] = "also should not copy"
    ActiveSupport::IsolatedExecutionState[:keep] = "keep this"

    t1 = Thread.current
    result = nil

    Thread.new do
      ActiveSupport::IsolatedExecutionState.share_with(t1, except: [:secret1, :secret2]) do
        result = {
          foo: ActiveSupport::IsolatedExecutionState[:foo],
          secret1: ActiveSupport::IsolatedExecutionState[:secret1],
          secret2: ActiveSupport::IsolatedExecutionState[:secret2],
          keep: ActiveSupport::IsolatedExecutionState[:keep]
        }
      end
    end.join

    assert_equal "bar", result[:foo]
    assert_nil result[:secret1]
    assert_nil result[:secret2]
    assert_equal "keep this", result[:keep]
  end
end
