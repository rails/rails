require 'abstract_unit'

class DispatcherTest < ActiveSupport::TestCase
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
    ActionDispatch::Callbacks.reset_callbacks(:call)
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

    dispatch do |env|
      raise "error"
    end rescue nil
    assert_equal 6, Foo.a
    assert_equal 6, Foo.b
  end

  def test_to_prepare_and_cleanup_delegation
    prepared = cleaned = false
    ActionDispatch::Callbacks.to_prepare { prepared = true }
    ActionDispatch::Callbacks.to_prepare { cleaned = true }

    ActionDispatch::Reloader.prepare!
    assert prepared

    ActionDispatch::Reloader.cleanup!
    assert cleaned
  end

  private

    def dispatch(&block)
      ActionDispatch::Callbacks.new(block || DummyApp.new).call(
        {'rack.input' => StringIO.new('')}
      )
    end

end
