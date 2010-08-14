require 'abstract_unit'

# Ensure deprecated dispatcher works
class DeprecatedDispatcherTest < ActiveSupport::TestCase
  class DummyApp
    def call(env)
      [200, {}, 'response']
    end
  end

  def setup
    ActionDispatch::Callbacks.reset_callbacks(:prepare)
    ActionDispatch::Callbacks.reset_callbacks(:call)
  end

  def test_assert_deprecated_to_prepare
    a = nil

    assert_deprecated do
      ActionController::Dispatcher.to_prepare { a = 1 }
    end

    assert_nil a
    dispatch
    assert_equal 1, a
  end

  def test_assert_deprecated_before_dispatch
    a = nil

    assert_deprecated do
      ActionController::Dispatcher.before_dispatch { a = 1 }
    end

    assert_nil a
    dispatch
    assert_equal 1, a
  end

  def test_assert_deprecated_after_dispatch
    a = nil

    assert_deprecated do
      ActionController::Dispatcher.after_dispatch { a = 1 }
    end

    assert_nil a
    dispatch
    assert_equal 1, a
  end

  private

    def dispatch(cache_classes = true)
      @dispatcher ||= ActionDispatch::Callbacks.new(DummyApp.new, !cache_classes)
      @dispatcher.call({'rack.input' => StringIO.new('')})
    end

end
