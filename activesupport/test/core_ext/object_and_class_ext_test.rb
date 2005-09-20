require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/object_and_class'

class ClassA; end
class ClassB < ClassA; end
class ClassC < ClassB; end
class ClassD < ClassA; end

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
end
