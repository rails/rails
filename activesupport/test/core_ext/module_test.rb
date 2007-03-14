require File.dirname(__FILE__) + '/../abstract_unit'

module One
  Constant1 = "Hello World"
  Constant2 = "What's up?"
end

class Ab
  include One
  Constant1 = "Hello World" # Will have different object id than One::Constant1
  Constant3 = "Goodbye World"
end

module Xy
  class Bc
    include One
  end
end

module Yz
  module Zy
    class Cd
      include One
    end
  end
end

class De
end

Somewhere = Struct.new(:street, :city)

Someone   = Struct.new(:name, :place) do
  delegate :street, :city, :to => :place
  delegate :state, :to => :@place
  delegate :upcase, :to => "place.city"
end

class Name
  delegate :upcase, :to => :@full_name

  def initialize(first, last)
    @full_name = "#{first} #{last}"
  end
end

$nowhere = <<-EOF
class Name
  delegate :nowhere
end
EOF

$noplace = <<-EOF
class Name
  delegate :noplace, :tos => :hollywood
end
EOF

class ModuleTest < Test::Unit::TestCase
  def test_included_in_classes
    assert One.included_in_classes.include?(Ab)
    assert One.included_in_classes.include?(Xy::Bc)
    assert One.included_in_classes.include?(Yz::Zy::Cd)
    assert !One.included_in_classes.include?(De)
  end

  def test_delegation_to_methods
    david = Someone.new("David", Somewhere.new("Paulina", "Chicago"))
    assert_equal "Paulina", david.street
    assert_equal "Chicago", david.city
  end

  def test_delegation_down_hierarchy
    david = Someone.new("David", Somewhere.new("Paulina", "Chicago"))
    assert_equal "CHICAGO", david.upcase
  end

  def test_delegation_to_instance_variable
    david = Name.new("David", "Hansson")
    assert_equal "DAVID HANSSON", david.upcase
  end

  def test_missing_delegation_target
    assert_raises(ArgumentError) { eval($nowhere) }
    assert_raises(ArgumentError) { eval($noplace) }
  end

  def test_parent
    assert_equal Yz::Zy, Yz::Zy::Cd.parent
    assert_equal Yz, Yz::Zy.parent
    assert_equal Object, Yz.parent
  end

  def test_parents
    assert_equal [Yz::Zy, Yz, Object], Yz::Zy::Cd.parents
    assert_equal [Yz, Object], Yz::Zy.parents
  end
  
  def test_local_constants
    assert_equal %w(Constant1 Constant3), Ab.local_constants.sort
  end

  def test_as_load_path
    assert_equal 'yz/zy', Yz::Zy.as_load_path
    assert_equal 'yz', Yz.as_load_path
  end
end

module BarMethodAliaser
  def self.included(foo_class)
    foo_class.send :include, BarMethods
    foo_class.alias_method_chain :bar, :baz
  end
end

module BarMethods
  def bar_with_baz
    bar_without_baz << '_with_baz'
  end

  def quux_with_baz!
    quux_without_baz! << '_with_baz'
  end

  def quux_with_baz?
    false
  end

  def quux_with_baz=(v)
    send(:quux_without_baz=, v) << '_with_baz'
  end
end

class MethodAliasingTest < Test::Unit::TestCase
  def setup
    Object.const_set(:FooClassWithBarMethod, Class.new)
    FooClassWithBarMethod.send(:define_method, 'bar', Proc.new { 'bar' })
    @instance = FooClassWithBarMethod.new
  end

  def teardown
    Object.send(:remove_const, :FooClassWithBarMethod)
  end

  def test_alias_method_chain
    assert @instance.respond_to?(:bar)
    feature_aliases = [:bar_with_baz, :bar_without_baz]

    feature_aliases.each do |method|
      assert !@instance.respond_to?(method)
    end

    assert_equal 'bar', @instance.bar

    FooClassWithBarMethod.send(:include, BarMethodAliaser)

    feature_aliases.each do |method|
      assert @instance.respond_to?(method)
    end

    assert_equal 'bar_with_baz', @instance.bar
    assert_equal 'bar', @instance.bar_without_baz
  end

  def test_alias_method_chain_with_punctuation_method
    FooClassWithBarMethod.send(:define_method, 'quux!', Proc.new { 'quux' })
    assert !@instance.respond_to?(:quux_with_baz!)
    FooClassWithBarMethod.send(:include, BarMethodAliaser)
    FooClassWithBarMethod.alias_method_chain :quux!, :baz
    assert @instance.respond_to?(:quux_with_baz!)

    assert_equal 'quux_with_baz', @instance.quux!
    assert_equal 'quux', @instance.quux_without_baz!
  end

  def test_alias_method_chain_with_same_names_between_predicates_and_bang_methods
    FooClassWithBarMethod.send(:define_method, 'quux!', Proc.new { 'quux!' })
    FooClassWithBarMethod.send(:define_method, 'quux?', Proc.new { true })
    FooClassWithBarMethod.send(:define_method, 'quux=', Proc.new { 'quux=' })
    assert !@instance.respond_to?(:quux_with_baz!)
    assert !@instance.respond_to?(:quux_with_baz?)
    assert !@instance.respond_to?(:quux_with_baz=)

    FooClassWithBarMethod.send(:include, BarMethodAliaser)
    assert @instance.respond_to?(:quux_with_baz!)
    assert @instance.respond_to?(:quux_with_baz?)
    assert @instance.respond_to?(:quux_with_baz=)


    FooClassWithBarMethod.alias_method_chain :quux!, :baz
    assert_equal 'quux!_with_baz', @instance.quux!
    assert_equal 'quux!', @instance.quux_without_baz!

    FooClassWithBarMethod.alias_method_chain :quux?, :baz
    assert_equal false, @instance.quux?
    assert_equal true,  @instance.quux_without_baz?

    FooClassWithBarMethod.alias_method_chain :quux=, :baz
    assert_equal 'quux=_with_baz', @instance.send(:quux=, 1234)
    assert_equal 'quux=', @instance.send(:quux_without_baz=, 1234)
  end

  def test_alias_method_chain_with_feature_punctuation
    FooClassWithBarMethod.send(:define_method, 'quux', Proc.new { 'quux' })
    FooClassWithBarMethod.send(:define_method, 'quux?', Proc.new { 'quux?' })
    FooClassWithBarMethod.send(:include, BarMethodAliaser)

    FooClassWithBarMethod.alias_method_chain :quux, :baz!
    assert_nothing_raised do
      assert_equal 'quux_with_baz', @instance.quux_with_baz!
    end

    assert_raise(NameError) do
      FooClassWithBarMethod.alias_method_chain :quux?, :baz!
    end
  end

  def test_alias_method_chain_yields_target_and_punctuation
    FooClassWithBarMethod.send(:define_method, :quux?, Proc.new { })
    FooClassWithBarMethod.send :include, BarMethods
    block_called = false
    FooClassWithBarMethod.alias_method_chain :quux?, :baz do |target, punctuation|
      block_called = true
      assert_equal 'quux', target
      assert_equal '?', punctuation
    end
    assert block_called
  end
end
