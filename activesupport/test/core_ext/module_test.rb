require 'abstract_unit'
require 'active_support/core_ext/module'

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

Somewhere = Struct.new(:street, :city) do
  attr_accessor :name
end

class Someone < Struct.new(:name, :place)
  delegate :street, :city, :to_f, :to => :place
  delegate :name=, :to => :place, :prefix => true
  delegate :upcase, :to => "place.city"
  delegate :table_name, :to => :class
  delegate :table_name, :to => :class, :prefix => true

  def self.table_name
    'some_table'
  end

  FAILED_DELEGATE_LINE = __LINE__ + 1
  delegate :foo, :to => :place

  FAILED_DELEGATE_LINE_2 = __LINE__ + 1
  delegate :bar, :to => :place, :allow_nil => true
end

Invoice   = Struct.new(:client) do
  delegate :street, :city, :name, :to => :client, :prefix => true
  delegate :street, :city, :name, :to => :client, :prefix => :customer
end

Project   = Struct.new(:description, :person) do
  delegate :name, :to => :person, :allow_nil => true
  delegate :to_f, :to => :description, :allow_nil => true
end

Developer = Struct.new(:client) do
  delegate :name, :to => :client, :prefix => nil
end

Tester = Struct.new(:client) do
  delegate :name, :to => :client, :prefix => false
end

class ParameterSet
  delegate :[], :[]=, :to => :@params

  def initialize
    @params = {:foo => "bar"}
  end
end

class Name
  delegate :upcase, :to => :@full_name

  def initialize(first, last)
    @full_name = "#{first} #{last}"
  end
end

class ModuleTest < ActiveSupport::TestCase
  def setup
    @david = Someone.new("David", Somewhere.new("Paulina", "Chicago"))
  end

  def test_delegation_to_methods
    assert_equal "Paulina", @david.street
    assert_equal "Chicago", @david.city
  end

  def test_delegation_to_assignment_method
    @david.place_name = "Fred"
    assert_equal "Fred", @david.place.name
  end

  def test_delegation_to_index_get_method
    @params = ParameterSet.new
    assert_equal "bar", @params[:foo]
  end

  def test_delegation_to_index_set_method
    @params = ParameterSet.new
    @params[:foo] = "baz"
    assert_equal "baz", @params[:foo]
  end

  def test_delegation_down_hierarchy
    assert_equal "CHICAGO", @david.upcase
  end

  def test_delegation_to_instance_variable
    david = Name.new("David", "Hansson")
    assert_equal "DAVID HANSSON", david.upcase
  end

  def test_delegation_to_class_method
    assert_equal 'some_table', @david.table_name
    assert_equal 'some_table', @david.class_table_name
  end

  def test_missing_delegation_target
    assert_raise(ArgumentError) do
      Name.send :delegate, :nowhere
    end
    assert_raise(ArgumentError) do
      Name.send :delegate, :noplace, :tos => :hollywood
    end
  end

  def test_delegation_prefix
    invoice = Invoice.new(@david)
    assert_equal invoice.client_name, "David"
    assert_equal invoice.client_street, "Paulina"
    assert_equal invoice.client_city, "Chicago"
  end

  def test_delegation_custom_prefix
    invoice = Invoice.new(@david)
    assert_equal invoice.customer_name, "David"
    assert_equal invoice.customer_street, "Paulina"
    assert_equal invoice.customer_city, "Chicago"
  end

  def test_delegation_prefix_with_nil_or_false
    assert_equal Developer.new(@david).name, "David"
    assert_equal Tester.new(@david).name, "David"
  end

  def test_delegation_prefix_with_instance_variable
    assert_raise ArgumentError do
      Class.new do
        def initialize(client)
          @client = client
        end
        delegate :name, :address, :to => :@client, :prefix => true
      end
    end
  end

  def test_delegation_with_allow_nil
    rails = Project.new("Rails", Someone.new("David"))
    assert_equal rails.name, "David"
  end

  def test_delegation_with_allow_nil_and_nil_value
    rails = Project.new("Rails")
    assert_nil rails.name
  end

  def test_delegation_with_allow_nil_and_nil_value_and_prefix
    Project.class_eval do
      delegate :name, :to => :person, :allow_nil => true, :prefix => true
    end
    rails = Project.new("Rails")
    assert_nil rails.person_name
  end

  def test_delegation_without_allow_nil_and_nil_value
    david = Someone.new("David")
    assert_raise(RuntimeError) { david.street }
  end

  def test_delegation_to_method_that_exists_on_nil
    nil_person = Someone.new(nil)
    assert_equal 0.0, nil_person.to_f
  end

  def test_delegation_to_method_that_exists_on_nil_when_allowing_nil
    nil_project = Project.new(nil)
    assert_equal 0.0, nil_project.to_f
  end

  def test_delegation_does_not_raise_error_when_removing_singleton_instance_methods
    parent = Class.new do
      def self.parent_method; end
    end

    assert_nothing_raised do
      Class.new(parent) do
        class << self
          delegate :parent_method, :to => :superclass
        end
      end
    end
  end

  def test_delegation_exception_backtrace
    someone = Someone.new("foo", "bar")
    someone.foo
  rescue NoMethodError => e
    file_and_line = "#{__FILE__}:#{Someone::FAILED_DELEGATE_LINE}"
    # We can't simply check the first line of the backtrace, because JRuby reports the call to __send__ in the backtrace.
    assert e.backtrace.any?{|a| a.include?(file_and_line)},
           "[#{e.backtrace.inspect}] did not include [#{file_and_line}]"
  end

  def test_delegation_exception_backtrace_with_allow_nil
    someone = Someone.new("foo", "bar")
    someone.bar
  rescue NoMethodError => e
    file_and_line = "#{__FILE__}:#{Someone::FAILED_DELEGATE_LINE_2}"
    # We can't simply check the first line of the backtrace, because JRuby reports the call to __send__ in the backtrace.
    assert e.backtrace.any?{|a| a.include?(file_and_line)},
           "[#{e.backtrace.inspect}] did not include [#{file_and_line}]"
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

  def test_local_constant_names
    ActiveSupport::Deprecation.silence do
      assert_equal %w(Constant1 Constant3), Ab.local_constant_names.sort.map(&:to_s)
    end
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

class MethodAliasingTest < ActiveSupport::TestCase
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
      assert_respond_to @instance, method
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
    assert_respond_to @instance, :quux_with_baz!

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
    assert_respond_to @instance, :quux_with_baz!
    assert_respond_to @instance, :quux_with_baz?
    assert_respond_to @instance, :quux_with_baz=


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

    assert_raise NoMethodError do
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

    assert_raise NoMethodError do
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
