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
class RemoveSubsTestClass2; end
class RemoveSubsBaseClass2
  def self.add_ivar
    @ivar = RemoveSubsTestClass2.new
  end
end
class RemoveSubsSubClass2 < RemoveSubsBaseClass2; end
class RemoveSubsTestClass3; end
class RemoveSubsBaseClass3
  def self.add_ivar
    @ivar = RemoveSubsTestClass3.new
  end
end
class RemoveSubsSubClass3 < RemoveSubsBaseClass3; end

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

  def test_remove_subclasses_of_multiple_classes_unsets_ivars
    r2 = RemoveSubsSubClass2.new
    RemoveSubsSubClass2.add_ivar
    r3 = RemoveSubsSubClass3.new
    RemoveSubsSubClass3.add_ivar
    
    Object.remove_subclasses_of(RemoveSubsBaseClass2, RemoveSubsBaseClass3)

    GC.start
    ObjectSpace.each_object do |o|
      flunk("ObjectSpace still contains RemoveSubsTestClass") if o.class == RemoveSubsTestClass
    end
  end
end
