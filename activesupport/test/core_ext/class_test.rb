require 'abstract_unit'

class A
end

module X
  class B
  end
end

module Y
  module Z
    class C
    end
  end
end

class ClassTest < Test::Unit::TestCase
  def test_removing_class_in_root_namespace
    assert A.is_a?(Class)
    Class.remove_class(A)
    assert_raises(NameError) { A.is_a?(Class) }
  end

  def test_removing_class_in_one_level_namespace
    assert X::B.is_a?(Class)
    Class.remove_class(X::B)
    assert_raises(NameError) { X::B.is_a?(Class) }
  end

  def test_removing_class_in_two_level_namespace
    assert Y::Z::C.is_a?(Class)
    Class.remove_class(Y::Z::C)
    assert_raises(NameError) { Y::Z::C.is_a?(Class) }
  end
  
  def test_retrieving_subclasses
    @parent   = eval("class D; end; D")
    @sub      = eval("class E < D; end; E")
    @subofsub = eval("class F < E; end; F")
    assert @parent.subclasses.all? { |i| [@sub.to_s, @subofsub.to_s].include?(i) }
    assert_equal 2, @parent.subclasses.size
    assert_equal [@subofsub.to_s], @sub.subclasses
    assert_equal [], @subofsub.subclasses
  end
end
