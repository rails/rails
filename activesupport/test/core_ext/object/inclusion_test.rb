require 'abstract_unit'
require 'active_support/core_ext/object/inclusion'

class InTest < Test::Unit::TestCase
  def test_in_array
    assert 1.in?([1,2])
    assert !3.in?([1,2])
  end

  def test_in_hash
    h = { "a" => 100, "b" => 200 }
    assert "a".in?(h)
    assert !"z".in?(h)
  end

  def test_in_string
    assert "lo".in?("hello")
    assert !"ol".in?("hello")
    assert ?h.in?("hello")
  end

  def test_in_range
    assert 25.in?(1..50)
    assert !75.in?(1..50)
  end

  def test_in_set
    s = Set.new([1,2])
    assert 1.in?(s)
    assert !3.in?(s)
  end

  def test_either
    assert 1.among?(1,2,3)
    assert !5.among?(1,2,3)
    assert [1,2,3].among?([1,2,3], 2, [3,4,5])
  end

  module A
  end
  class B
    include A
  end
  class C < B
  end

  def test_in_module
    assert A.in?(B)
    assert A.in?(C)
    assert !A.in?(A)
  end
end
