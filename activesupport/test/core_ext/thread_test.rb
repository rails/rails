require 'abstract_unit'
require 'active_support/core_ext/thread'

class ThreadExt < ActiveSupport::TestCase
  def test_main_thread_variable_in_enumerator
    assert_equal Thread.main, Thread.current

    Thread.current.thread_variable_set :foo, "bar"

    thread, value = Fiber.new {
      Fiber.yield [Thread.current, Thread.current.thread_variable_get(:foo)]
    }.resume

    assert_equal Thread.current, thread
    assert_equal Thread.current.thread_variable_get(:foo), value
  end

  def test_thread_variable_in_enumerator
    Thread.new {
      Thread.current.thread_variable_set :foo, "bar"

      thread, value = Fiber.new {
        Fiber.yield [Thread.current, Thread.current.thread_variable_get(:foo)]
      }.resume

      assert_equal Thread.current, thread
      assert_equal Thread.current.thread_variable_get(:foo), value
    }.join
  end

  def test_thread_variables
    assert_equal [], Thread.new { Thread.current.thread_variables }.join.value

    t = Thread.new {
      Thread.current.thread_variable_set(:foo, "bar")
      Thread.current.thread_variables
    }
    assert_equal [:foo], t.join.value
  end

  def test_thread_variable?
    refute Thread.new { Thread.current.thread_variable?("foo") }.join.value
    t = Thread.new {
      Thread.current.thread_variable_set("foo", "bar")
    }.join

    assert t.thread_variable?("foo")
    assert t.thread_variable?(:foo)
    refute t.thread_variable?(:bar)
  end

  def test_thread_variable_strings_and_symbols_are_the_same_key
    t = Thread.new {}.join
    t.thread_variable_set("foo", "bar")
    assert_equal "bar", t.thread_variable_get(:foo)
  end

  def test_thread_variable_frozen
    t = Thread.new { }.join
    t.freeze
    assert_raises(RuntimeError) do
      t.thread_variable_set(:foo, "bar")
    end
  end

  def test_thread_variable_security
    t = Thread.new { sleep }

    assert_raises(SecurityError) do
      Thread.new { $SAFE = 4; t.thread_variable_get(:foo) }.join
    end

    assert_raises(SecurityError) do
      Thread.new { $SAFE = 4; t.thread_variable_set(:foo, :baz) }.join
    end
  end
end
