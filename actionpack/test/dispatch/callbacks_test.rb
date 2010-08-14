require 'abstract_unit'

class DispatcherTest < Test::Unit::TestCase
  class Foo
    cattr_accessor :a, :b
  end

  class DummyApp
    def call(env)
      [200, {}, 'response']
    end
  end

  def setup
    Foo.a, Foo.b = 0, 0
    ActionDispatch::Callbacks.reset_callbacks(:prepare)
    ActionDispatch::Callbacks.reset_callbacks(:call)
  end

  def test_prepare_callbacks_with_cache_classes
    a = b = c = nil
    ActionDispatch::Callbacks.to_prepare { |*args| a = b = c = 1 }
    ActionDispatch::Callbacks.to_prepare { |*args| b = c = 2 }
    ActionDispatch::Callbacks.to_prepare { |*args| c = 3 }

    # Ensure to_prepare callbacks are not run when defined
    assert_nil a || b || c

    # Run callbacks
    dispatch

    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c

    # Make sure they are only run once
    a = b = c = nil
    dispatch
    assert_nil a || b || c
  end

  def test_prepare_callbacks_without_cache_classes
    a = b = c = nil
    ActionDispatch::Callbacks.to_prepare { |*args| a = b = c = 1 }
    ActionDispatch::Callbacks.to_prepare { |*args| b = c = 2 }
    ActionDispatch::Callbacks.to_prepare { |*args| c = 3 }

    # Ensure to_prepare callbacks are not run when defined
    assert_nil a || b || c

    # Run callbacks
    dispatch(false)

    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c

    # Make sure they are run again
    a = b = c = nil
    dispatch(false)
    assert_equal 1, a
    assert_equal 2, b
    assert_equal 3, c
  end

  def test_to_prepare_with_identifier_replaces
    ActionDispatch::Callbacks.to_prepare(:unique_id) { |*args| Foo.a, Foo.b = 1, 1 }
    ActionDispatch::Callbacks.to_prepare(:unique_id) { |*args| Foo.a = 2 }

    dispatch
    assert_equal 2, Foo.a
    assert_equal 0, Foo.b
  end

  def test_before_and_after_callbacks
    ActionDispatch::Callbacks.before { |*args| Foo.a += 1; Foo.b += 1 }
    ActionDispatch::Callbacks.after  { |*args| Foo.a += 1; Foo.b += 1 }

    dispatch
    assert_equal 2, Foo.a
    assert_equal 2, Foo.b

    dispatch
    assert_equal 4, Foo.a
    assert_equal 4, Foo.b
  end

  private

    def dispatch(cache_classes = true, &block)
      @dispatcher ||= ActionDispatch::Callbacks.new(block || DummyApp.new, !cache_classes)
      @dispatcher.call({'rack.input' => StringIO.new('')})
    end

end
