require "abstract_unit"

class ExecutorTest < ActiveSupport::TestCase
  class DummyError < RuntimeError
  end

  def test_wrap_invokes_callbacks
    called = []
    executor.to_run { called << :run }
    executor.to_complete { called << :complete }

    executor.wrap do
      called << :body
    end

    assert_equal [:run, :body, :complete], called
  end

  def test_callbacks_share_state
    result = false
    executor.to_run { @foo = true }
    executor.to_complete { result = @foo }

    executor.wrap { }

    assert result
  end

  def test_separated_calls_invoke_callbacks
    called = []
    executor.to_run { called << :run }
    executor.to_complete { called << :complete }

    state = executor.run!
    called << :body
    state.complete!

    assert_equal [:run, :body, :complete], called
  end

  def test_exceptions_unwind
    called = []
    executor.to_run { called << :run_1 }
    executor.to_run { raise DummyError }
    executor.to_run { called << :run_2 }
    executor.to_complete { called << :complete }

    assert_raises(DummyError) do
      executor.wrap { called << :body }
    end

    assert_equal [:run_1, :complete], called
  end

  def test_avoids_double_wrapping
    called = []
    executor.to_run { called << :run }
    executor.to_complete { called << :complete }

    executor.wrap do
      called << :early
      executor.wrap do
        called << :body
      end
      called << :late
    end

    assert_equal [:run, :early, :body, :late, :complete], called
  end

  def test_hooks_carry_state
    supplied_state = :none

    hook = Class.new do
      define_method(:run) do
        :some_state
      end

      define_method(:complete) do |state|
        supplied_state = state
      end
    end.new

    executor.register_hook(hook)

    executor.wrap { }

    assert_equal :some_state, supplied_state
  end

  def test_nil_state_is_sufficient
    supplied_state = :none

    hook = Class.new do
      define_method(:run) do
        nil
      end

      define_method(:complete) do |state|
        supplied_state = state
      end
    end.new

    executor.register_hook(hook)

    executor.wrap { }

    assert_equal nil, supplied_state
  end

  def test_exception_skips_uninvoked_hook
    supplied_state = :none

    hook = Class.new do
      define_method(:run) do
        :some_state
      end

      define_method(:complete) do |state|
        supplied_state = state
      end
    end.new

    executor.to_run do
      raise DummyError
    end
    executor.register_hook(hook)

    assert_raises(DummyError) do
      executor.wrap { }
    end

    assert_equal :none, supplied_state
  end

  def test_exception_unwinds_invoked_hook
    supplied_state = :none

    hook = Class.new do
      define_method(:run) do
        :some_state
      end

      define_method(:complete) do |state|
        supplied_state = state
      end
    end.new

    executor.register_hook(hook)
    executor.to_run do
      raise DummyError
    end

    assert_raises(DummyError) do
      executor.wrap { }
    end

    assert_equal :some_state, supplied_state
  end

  def test_separate_classes_can_wrap
    other_executor = Class.new(ActiveSupport::Executor)

    called = []
    executor.to_run { called << :run }
    executor.to_complete { called << :complete }
    other_executor.to_run { called << :other_run }
    other_executor.to_complete { called << :other_complete }

    executor.wrap do
      other_executor.wrap do
        called << :body
      end
    end

    assert_equal [:run, :other_run, :body, :other_complete, :complete], called
  end

  private
    def executor
      @executor ||= Class.new(ActiveSupport::Executor)
    end
end
