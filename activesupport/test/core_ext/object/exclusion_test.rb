require 'abstract_unit'
require 'active_support/core_ext/object/exclusion'

class NotInTest < ActiveSupport::TestCase
  def test_in_array
    assert 3.not_in?([1,2])
    assert !1.not_in?([1,2])
  end

  def test_in_hash
    h = { a: 100, b: 200 }
    assert !:a.not_in?(h)
    assert :z.not_in?(h)
  end

  def test_in_string
    assert !"lo".not_in?("hello")
    assert "ol".not_in?("hello")
    assert !?h.not_in?("hello")
  end

  def test_in_range
    assert !25.not_in?(1..50)
    assert 75.not_in?(1..50)
  end

  def test_in_set
    s = Set.new([1,2])
    assert !1.not_in?(s)
    assert 3.not_in?(s)
  end

  module A
  end
  class B
    include A
  end
  class C < B
  end

  def test_in_module
    assert !A.not_in?(B)
    assert !A.not_in?(C)
    assert A.not_in?(A)
  end
  
  def test_no_method_catching
    assert_raise(ArgumentError) { 1.not_in?(1) }
  end
end
