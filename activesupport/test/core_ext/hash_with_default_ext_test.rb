require 'abstract_unit'
require 'active_support/core_ext/hash/with_default'

class HashWithDefaultExtTest < ActiveSupport::TestCase
  def setup
    @hash = {a: 1}
    @hash.default = :z
  end

  def test_block
    assert_equal @hash.with_default{:c}[:b], :c
  end

  def test_param
    c = Object.new
    assert_equal @hash.with_default(c)[:b], c
  end

  def test_too_many_arguments
    assert_raises ArgumentError do
      @hash.with_default(:c) { :c }
    end
  end

  def test_too_few_arguments
    assert_raises ArgumentError do
      @hash.with_default
    end
  end

  def test_conflicting_arguments
    assert_raises ArgumentError do
      @hash.with_default(:c, :d)
    end
  end
end
