require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/object_and_class'

class ClassA; end
class ClassB < ClassA; end
class ClassC < ClassB; end
class ClassD < ClassA; end
class RemoveSubsTestClass; end
class RemoveSubsBaseClass
  def self.add_ivar
    @ivar = RemoveSubsTestClass.new
  end
end
class RemoveSubsSubClass < RemoveSubsBaseClass; end

class ClassExtTest < Test::Unit::TestCase
  def test_methods
    assert defined?(ClassB)
    assert defined?(ClassC)
    assert defined?(ClassD)

    ClassA.remove_subclasses

    assert !defined?(ClassB)
    assert !defined?(ClassC)
    assert !defined?(ClassD)
  end
end

class ObjectTests < Test::Unit::TestCase
  def test_suppress_re_raises
    assert_raises(LoadError) { suppress(ArgumentError) {raise LoadError} }
  end
  def test_suppress_supresses
    suppress(ArgumentError) { raise ArgumentError }
    suppress(LoadError) { raise LoadError }
    suppress(LoadError, ArgumentError) { raise LoadError }
    suppress(LoadError, ArgumentError) { raise ArgumentError }
  end
  
  def test_remove_subclasses_of_unsets_ivars
    r = RemoveSubsSubClass.new
    RemoveSubsSubClass.add_ivar
    RemoveSubsBaseClass.remove_subclasses

    GC.start
    ObjectSpace.each_object do |o|
      flunk("ObjectSpace still contains RemoveSubsTestClass") if o.class == RemoveSubsTestClass
    end
  end
end