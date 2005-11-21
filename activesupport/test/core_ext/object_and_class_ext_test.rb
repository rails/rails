require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/object_and_class'

class ClassA; end
class ClassB < ClassA; end
class ClassC < ClassB; end
class ClassD < ClassA; end

module Bar
  def bar; end
end

module Baz
  def baz; end
end

class Foo
  include Bar
end

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
 
  def test_extended_by
    foo = Foo.new
    assert_equal [Bar], foo.extended_by
    foo.extend(Baz)
    assert_equal %w(Bar Baz), foo.extended_by.map {|mod| mod.name}.sort
  end
  
  def test_extend_with_included_modules_from
    foo, object = Foo.new, Object.new
    assert !object.respond_to?(:bar)
    assert !object.respond_to?(:baz)
    
    object.extend_with_included_modules_from(foo)
    assert object.respond_to?(:bar)
    assert !object.respond_to?(:baz)
    
    foo.extend(Baz)
    object.extend_with_included_modules_from(foo)
    assert object.respond_to?(:bar)
    assert object.respond_to?(:baz)
  end

end

class ObjectInstanceVariableTest < Test::Unit::TestCase
  def setup
    @source, @dest = Object.new, Object.new
    @source.instance_variable_set(:@bar, 'bar')
    @source.instance_variable_set(:@baz, 'baz')
  end

  def test_copy_instance_variables_from_without_explicit_excludes
    assert_equal [], @dest.instance_variables
    @dest.copy_instance_variables_from(@source)

    assert_equal %w(@bar @baz), @dest.instance_variables.sort
    %w(@bar @baz).each do |name|
      assert_equal @source.instance_variable_get(name).object_id, 
                   @dest.instance_variable_get(name).object_id
    end
  end
  
  def test_copy_instance_variables_from_with_explicit_excludes
    @dest.copy_instance_variables_from(@source, ['@baz'])
    assert !@dest.instance_variables.include?('@baz')
    assert_equal 'bar', @dest.instance_variable_get('@bar')
  end
  
  def test_copy_instance_variables_automatically_excludes_protected_instance_variables
    @source.instance_variable_set(:@quux, 'quux')
    class << @source
      def protected_instance_variables
        ['@bar', :@quux]
      end
    end
    
    @dest.copy_instance_variables_from(@source)
    assert !@dest.instance_variables.include?('@bar')
    assert !@dest.instance_variables.include?('@quux')
    assert_equal 'baz', @dest.instance_variable_get('@baz')
  end
end
