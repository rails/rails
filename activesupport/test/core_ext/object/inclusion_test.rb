# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/object/inclusion"

class InTest < ActiveSupport::TestCase
  def test_in_array
    assert 1.in?([1, 2])
    assert_not 3.in?([1, 2])
  end

  def test_in_hash
    h = { "a" => 100, "b" => 200 }
    assert "a".in?(h)
    assert_not "z".in?(h)
  end

  def test_in_string
    assert "lo".in?("hello")
    assert_not "ol".in?("hello")
    assert ?h.in?("hello")
  end

  def test_in_range
    assert 25.in?(1..50)
    assert_not 75.in?(1..50)
  end

  def test_in_set
    s = Set.new([1, 2])
    assert 1.in?(s)
    assert_not 3.in?(s)
  end

  module A
  end
  class B
    include A
  end
  class C < B
  end
  class D
  end

  def test_in_module
    assert A.in?(B)
    assert A.in?(C)
    assert_not A.in?(A)
    assert_not A.in?(D)
  end

  def test_no_method_catching
    assert_raise(ArgumentError) { 1.in?(1) }
  end

  def test_presence_in
    assert_equal "stuff", "stuff".presence_in(%w( lots of stuff ))
    assert_nil "stuff".presence_in(%w( lots of crap ))
    assert_raise(ArgumentError) { 1.presence_in(1) }
  end
end
