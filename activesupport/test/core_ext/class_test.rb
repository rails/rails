require 'abstract_unit'
require 'active_support/core_ext/class'

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
  def test_retrieving_subclasses
    @parent   = eval("class D; end; D")
    @sub      = eval("class E < D; end; E")
    @subofsub = eval("class F < E; end; F")
    assert_equal 2, @parent.subclasses.size
    assert_equal [@subofsub.to_s], @sub.subclasses
    assert_equal [], @subofsub.subclasses
    assert_equal [@sub.to_s, @subofsub.to_s].sort, @parent.subclasses.sort
  end
end
