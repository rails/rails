require 'abstract_unit'
require 'active_support/core_ext/object/exclusion'

class NotInTest < ActiveSupport::TestCase
  def test_not_in_array
    assert 1.not_in?([2, 3])
    assert_not 2.not_in?([1,2])
  end

  def test_not_in_hash
    h = { "a" => 100, "b" => 200 }
    assert "z".not_in?(h)
    assert_not "a".not_in?(h)
  end

  def test_not_in_string
    assert "ol".not_in?("hello")
    assert_not "lo".not_in?("hello")
    assert ?z.not_in?("hello")
  end

  def test_not_in_range
    assert 75.not_in?(1..50)
    assert_not 25.not_in?(1..50)
  end

  def test_not_in_set
    s = Set.new([1,2])
    assert 3.not_in?(s)
    assert_not 1.not_in?(s)
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

  def test_not_in_module
    assert A.not_in?(D)
    assert A.not_in?(A)
    assert_not A.not_in?(B)
    assert_not A.not_in?(C)
  end

  def test_no_method_catching
    assert_raise(ArgumentError) { 1.not_in?(1) }
  end
end
