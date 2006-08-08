require File.dirname(__FILE__) + '/abstract_unit'
require File.join(File.dirname(File.dirname(__FILE__)), 'lib/active_support/caching_tools.rb')

class HashCachingTests < Test::Unit::TestCase
  def cached(&proc)
    return @cached if defined?(@cached)

    @cached_class = Class.new(&proc)
    @cached_class.class_eval do
      extend ActiveSupport::CachingTools::HashCaching
      hash_cache :slow_method
    end
    @cached = @cached_class.new
  end

  def test_cache_access_should_call_method
    cached do
      def slow_method(a) raise "I should be here: #{a}"; end
    end
    assert_raises(RuntimeError) { cached.slow_method_cache[1] }
  end

  def test_cache_access_should_actually_cache
    cached do
      def slow_method(a)
        (@x ||= [])
        if @x.include?(a) then raise "Called twice for #{a}!"
        else
          @x << a
          a + 1
        end
      end
    end
    assert_equal 11, cached.slow_method_cache[10]
    assert_equal 12, cached.slow_method_cache[11]
    assert_equal 11, cached.slow_method_cache[10]
    assert_equal 12, cached.slow_method_cache[11]
  end

  def test_cache_should_be_clearable
    cached do
      def slow_method(a)
        @x ||= 0
        @x += 1
      end
    end
    assert_equal 1, cached.slow_method_cache[:a]
    assert_equal 2, cached.slow_method_cache[:b]
    assert_equal 3, cached.slow_method_cache[:c]

    assert_equal 1, cached.slow_method_cache[:a]
    assert_equal 2, cached.slow_method_cache[:b]
    assert_equal 3, cached.slow_method_cache[:c]

    cached.slow_method_cache.clear

    assert_equal 4, cached.slow_method_cache[:a]
    assert_equal 5, cached.slow_method_cache[:b]
    assert_equal 6, cached.slow_method_cache[:c]
  end

  def test_deep_caches_should_work_too
    cached do
      def slow_method(a, b, c)
        a + b + c
      end
    end
    assert_equal 3, cached.slow_method_cache[1][1][1]
    assert_equal 7, cached.slow_method_cache[1][2][4]
    assert_equal 7, cached.slow_method_cache[1][2][4]
    assert_equal 7, cached.slow_method_cache[4][2][1]

    assert_equal({
      1 => {1 => {1 => 3}, 2 => {4 => 7}},
      4 => {2 => {1 => 7}}},
      cached.slow_method_cache
    )
  end
end
