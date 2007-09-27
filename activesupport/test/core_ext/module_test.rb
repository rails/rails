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
    assert_equal %w(Constant1 Constant3), Ab.local_constants.sort.map(&:to_s)
  end

  def test_as_load_path
    assert_equal 'yz/zy', Yz::Zy.as_load_path
    assert_equal 'yz', Yz.as_load_path
  end
end

module BarMethodAliaser
  def self.included(foo_class)
    foo_class.class_eval do
      include BarMethods
      alias_method_chain :bar, :baz
    end
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

  def duck_with_orange
    duck_without_orange << '_with_orange'
  end
end

class MethodAliasingTest < Test::Unit::TestCase
  def setup
    Object.const_set :FooClassWithBarMethod, Class.new { def bar() 'bar' end }
    @instance = FooClassWithBarMethod.new
  end

  def teardown
    Object.instance_eval { remove_const :FooClassWithBarMethod }
  end

  def test_alias_method_chain
    assert @instance.respond_to?(:bar)
    feature_aliases = [:bar_with_baz, :bar_without_baz]

    feature_aliases.each do |method|
      assert !@instance.respond_to?(method)
    end

    assert_equal 'bar', @instance.bar

    FooClassWithBarMethod.class_eval { include BarMethodAliaser }

    feature_aliases.each do |method|
      assert @instance.respond_to?(method)
    end

    assert_equal 'bar_with_baz', @instance.bar
    assert_equal 'bar', @instance.bar_without_baz
  end

  def test_alias_method_chain_with_punctuation_method
    FooClassWithBarMethod.class_eval do
      def quux!; 'quux' end
    end

    assert !@instance.respond_to?(:quux_with_baz!)
    FooClassWithBarMethod.class_eval do
      include BarMethodAliaser
      alias_method_chain :quux!, :baz
    end
    assert @instance.respond_to?(:quux_with_baz!)

    assert_equal 'quux_with_baz', @instance.quux!
    assert_equal 'quux', @instance.quux_without_baz!
  end

  def test_alias_method_chain_with_same_names_between_predicates_and_bang_methods
    FooClassWithBarMethod.class_eval do
      def quux!; 'quux!' end
      def quux?; true end
      def quux=(v); 'quux=' end
    end

    assert !@instance.respond_to?(:quux_with_baz!)
    assert !@instance.respond_to?(:quux_with_baz?)
    assert !@instance.respond_to?(:quux_with_baz=)

    FooClassWithBarMethod.class_eval { include BarMethodAliaser }
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
    FooClassWithBarMethod.class_eval do
      def quux; 'quux' end
      def quux?; 'quux?' end
      include BarMethodAliaser
      alias_method_chain :quux, :baz!
    end

    assert_nothing_raised do
      assert_equal 'quux_with_baz', @instance.quux_with_baz!
    end

    assert_raise(NameError) do
      FooClassWithBarMethod.alias_method_chain :quux?, :baz!
    end
  end

  def test_alias_method_chain_yields_target_and_punctuation
    args = nil

    FooClassWithBarMethod.class_eval do
      def quux?; end
      include BarMethods

      FooClassWithBarMethod.alias_method_chain :quux?, :baz do |target, punctuation|
        args = [target, punctuation]
      end
    end

    assert_not_nil args
    assert_equal 'quux', args[0]
    assert_equal '?', args[1]
  end

  def test_alias_method_chain_preserves_private_method_status
    FooClassWithBarMethod.class_eval do
      def duck; 'duck' end
      include BarMethodAliaser
      private :duck
      alias_method_chain :duck, :orange
    end

    assert_raises NoMethodError do
      @instance.duck
    end

    assert_equal 'duck_with_orange', @instance.instance_eval { duck }
    assert FooClassWithBarMethod.private_method_defined?(:duck)
  end

  def test_alias_method_chain_preserves_protected_method_status
    FooClassWithBarMethod.class_eval do
      def duck; 'duck' end
      include BarMethodAliaser
      protected :duck
      alias_method_chain :duck, :orange
    end

    assert_raises NoMethodError do
      @instance.duck
    end

    assert_equal 'duck_with_orange', @instance.instance_eval { duck }
    assert FooClassWithBarMethod.protected_method_defined?(:duck)
  end

  def test_alias_method_chain_preserves_public_method_status
    FooClassWithBarMethod.class_eval do
      def duck; 'duck' end
      include BarMethodAliaser
      public :duck
      alias_method_chain :duck, :orange
    end

    assert_equal 'duck_with_orange', @instance.duck
    assert FooClassWithBarMethod.public_method_defined?(:duck)
  end
end
