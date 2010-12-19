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
  end

  def test_to_prepare_deprecation
    prepared = false
    assert_deprecated do
      ActionDispatch::Callbacks.to_prepare { prepared = true }
    end

    ActionDispatch::Reloader.prepare!
    assert prepared
  end

  private

    def dispatch(&block)
      @dispatcher ||= ActionDispatch::Callbacks.new(block || DummyApp.new)
      @dispatcher.call({'rack.input' => StringIO.new('')})
    end

end
