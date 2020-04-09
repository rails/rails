# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/array"

class WrapTest < ActiveSupport::TestCase
  class FakeCollection
    def to_ary
      ["foo", "bar"]
    end
  end

  class Proxy
    def initialize(target) @target = target end
    def method_missing(*a) @target.send(*a) end
  end

  class DoubtfulToAry
    def to_ary
      :not_an_array
    end
  end

  class NilToAry
    def to_ary
      nil
    end
  end

  def test_array
    ary = %w(foo bar)
    assert_same ary, Array.wrap(ary)
  end

  def test_nil
    assert_equal [], Array.wrap(nil)
  end

  def test_object
    o = Object.new
    assert_equal [o], Array.wrap(o)
  end

  def test_string
    assert_equal ["foo"], Array.wrap("foo")
  end

  def test_string_with_newline
    assert_equal ["foo\nbar"], Array.wrap("foo\nbar")
  end

  def test_object_with_to_ary
    assert_equal ["foo", "bar"], Array.wrap(FakeCollection.new)
  end

  def test_proxy_object
    p = Proxy.new(Object.new)
    assert_equal [p], Array.wrap(p)
  end

  def test_proxy_to_object_with_to_ary
    p = Proxy.new(FakeCollection.new)
    assert_equal [p], Array.wrap(p)
  end

  def test_struct
    o = Struct.new(:foo).new(123)
    assert_equal [o], Array.wrap(o)
  end

  def test_wrap_returns_wrapped_if_to_ary_returns_nil
    o = NilToAry.new
    assert_equal [o], Array.wrap(o)
  end

  def test_wrap_does_not_complain_if_to_ary_does_not_return_an_array
    assert_equal DoubtfulToAry.new.to_ary, Array.wrap(DoubtfulToAry.new)
  end
end
