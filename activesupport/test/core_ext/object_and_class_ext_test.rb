require File.dirname(__FILE__) + '/../abstract_unit'

class ClassA; end
class ClassB < ClassA; end
class ClassC < ClassB; end
class ClassD < ClassA; end

class ClassI; end
class ClassJ < ClassI; end

class ClassK
end
module Nested
  class ClassL < ClassK
  end
end

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

  def test_subclasses_of
    assert_equal [ClassJ], Object.subclasses_of(ClassI)
    ClassI.remove_subclasses
    assert_equal [], Object.subclasses_of(ClassI)
  end

  def test_subclasses_of_should_find_nested_classes
    assert Object.subclasses_of(ClassK).include?(Nested::ClassL)
  end

  def test_subclasses_of_should_not_return_removed_classes
    # First create the removed class
    old_class = Nested.send :remove_const, :ClassL
    new_class = Class.new(ClassK)
    Nested.const_set :ClassL, new_class
    assert_equal "Nested::ClassL", new_class.name # Sanity check

    subclasses = Object.subclasses_of(ClassK)
    assert subclasses.include?(new_class)
    assert ! subclasses.include?(old_class)
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
    assert foo.extended_by.include?(Bar)
    foo.extend(Baz)
    assert(([Bar, Baz] - foo.extended_by).empty?, "Expected Bar, Baz in #{foo.extended_by.inspect}")
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

  def test_instance_values
    object = Object.new
    object.instance_variable_set :@a, 1
    object.instance_variable_set :@b, 2
    assert_equal({'a' => 1, 'b' => 2}, object.instance_values)
  end

  def test_instance_exec_passes_arguments_to_block
    block = Proc.new { |value| [self, value] }
    assert_equal %w(hello goodbye), 'hello'.instance_exec('goodbye', &block)
  end

end
