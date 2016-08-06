require "abstract_unit"

class LazyLoadHooksTest < ActiveSupport::TestCase
  def test_basic_hook
    i = 0
    ActiveSupport.on_load(:basic_hook) { i += 1 }
    ActiveSupport.run_load_hooks(:basic_hook)
    assert_equal 1, i
  end

  def test_basic_hook_with_two_registrations
    i = 0
    ActiveSupport.on_load(:basic_hook_with_two) { i += incr }
    assert_equal 0, i
    ActiveSupport.run_load_hooks(:basic_hook_with_two, FakeContext.new(2))
    assert_equal 2, i
    ActiveSupport.run_load_hooks(:basic_hook_with_two, FakeContext.new(5))
    assert_equal 7, i
  end

  def test_hook_registered_after_run
    i = 0
    ActiveSupport.run_load_hooks(:registered_after)
    assert_equal 0, i
    ActiveSupport.on_load(:registered_after) { i += 1 }
    assert_equal 1, i
  end

  def test_hook_registered_after_run_with_two_registrations
    i = 0
    ActiveSupport.run_load_hooks(:registered_after_with_two, FakeContext.new(2))
    ActiveSupport.run_load_hooks(:registered_after_with_two, FakeContext.new(5))
    assert_equal 0, i
    ActiveSupport.on_load(:registered_after_with_two) { i += incr }
    assert_equal 7, i
  end

  def test_hook_registered_interleaved_run_with_two_registrations
    i = 0
    ActiveSupport.run_load_hooks(:registered_interleaved_with_two, FakeContext.new(2))
    assert_equal 0, i
    ActiveSupport.on_load(:registered_interleaved_with_two) { i += incr }
    assert_equal 2, i
    ActiveSupport.run_load_hooks(:registered_interleaved_with_two, FakeContext.new(5))
    assert_equal 7, i
  end

  def test_hook_receives_a_context
    i = 0
    ActiveSupport.on_load(:contextual) { i += incr }
    assert_equal 0, i
    ActiveSupport.run_load_hooks(:contextual, FakeContext.new(2))
    assert_equal 2, i
  end

  def test_hook_receives_a_context_afterward
    i = 0
    ActiveSupport.run_load_hooks(:contextual_after, FakeContext.new(2))
    assert_equal 0, i
    ActiveSupport.on_load(:contextual_after) { i += incr }
    assert_equal 2, i
  end

  def test_hook_with_yield_true
    i = 0
    ActiveSupport.on_load(:contextual_yield, yield: true) do |obj|
      i += obj.incr + incr_amt
    end
    assert_equal 0, i
    ActiveSupport.run_load_hooks(:contextual_yield, FakeContext.new(2))
    assert_equal 7, i
  end

  def test_hook_with_yield_true_afterward
    i = 0
    ActiveSupport.run_load_hooks(:contextual_yield_after, FakeContext.new(2))
    assert_equal 0, i
    ActiveSupport.on_load(:contextual_yield_after, yield: true) do |obj|
      i += obj.incr + incr_amt
    end
    assert_equal 7, i
  end

private

  def incr_amt
    5
  end

  class FakeContext
    attr_reader :incr
    def initialize(incr)
      @incr = incr
    end
  end
end