require 'abstract_unit'

class ExecutorTest < ActiveSupport::TestCase
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
