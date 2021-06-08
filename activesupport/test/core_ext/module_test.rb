# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/module"

Somewhere = Struct.new(:street, :city) do
  attr_accessor :name
end

Someone = Struct.new(:name, :place) do
  delegate :street, :city, :to_f, to: :place
  delegate :name=, to: :place, prefix: true
  delegate :upcase, to: "place.city"
  delegate :table_name, to: :class
  delegate :table_name, to: :class, prefix: true

  def self.table_name
    "some_table"
  end

  self::FAILED_DELEGATE_LINE = __LINE__ + 1
  delegate :foo, to: :place

  self::FAILED_DELEGATE_LINE_2 = __LINE__ + 1
  delegate :bar, to: :place, allow_nil: true

  def kw_send(method:)
    public_send(method)
  end

  private
    def private_name
      "Private"
    end
end

Invoice = Struct.new(:client) do
  delegate :street, :city, :name, to: :client, prefix: true
  delegate :street, :city, :name, to: :client, prefix: :customer
end

Project = Struct.new(:description, :person) do
  delegate :name, to: :person, allow_nil: true
  delegate :to_f, to: :description, allow_nil: true
end

Developer = Struct.new(:client) do
  delegate :name, to: :client, prefix: nil
end

Event = Struct.new(:case) do
  delegate :foo, to: :case
end

Tester = Struct.new(:client) do
  delegate :name, to: :client, prefix: false

  def foo; 1; end
end

Product = Struct.new(:name) do
  delegate :name, to: :manufacturer, prefix: true
  delegate :name, to: :type, prefix: true

  def manufacturer
    @manufacturer ||= nil.unknown_method
  end

  def type
    @type ||= nil.type_name
  end
end

module ExtraMissing
  def method_missing(sym, *args)
    if sym == :extra_missing
      42
    else
      super
    end
  end

  def respond_to_missing?(sym, priv = false)
    sym == :extra_missing || super
  end
end

DecoratedTester = Struct.new(:client) do
  include ExtraMissing

  delegate_missing_to :client
end

class DecoratedMissingAllowNil
  delegate_missing_to :case, allow_nil: true

  attr_reader :case

  def initialize(kase)
    @case = kase
  end
end

class DecoratedReserved
  delegate_missing_to :case

  attr_reader :case

  def initialize(kase)
    @case = kase
  end
end

class Maze
  attr_accessor :cavern, :passages
end

class Cavern
  delegate_missing_to :target

  attr_reader :maze

  def initialize(maze)
    @maze = maze
  end

  def target
    @maze.passages = :twisty
  end
end

class Block
  def hello?
    true
  end
end

HasBlock = Struct.new(:block) do
  delegate :hello?, to: :block
end

class ParameterSet
  delegate :[], :[]=, to: :@params

  def initialize
    @params = { foo: "bar" }
  end
end

class Name
  delegate :upcase, to: :@full_name

  def initialize(first, last)
    @full_name = "#{first} #{last}"
  end
end

class SideEffect
  attr_reader :ints

  delegate :to_i, to: :shift, allow_nil: true
  delegate :to_s, to: :shift

  def initialize
    @ints = [1, 2, 3]
  end

  def shift
    @ints.shift
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
    assert_equal "some_table", @david.table_name
    assert_equal "some_table", @david.class_table_name
  end

  def test_missing_delegation_target
    assert_raise(ArgumentError) do
      Name.send :delegate, :nowhere
    end
    assert_raise(ArgumentError) do
      Name.send :delegate, :noplace, tos: :hollywood
    end
  end

  def test_delegation_target_when_prefix_is_true
    assert_nothing_raised do
      Name.send :delegate, :go, to: :you, prefix: true
    end
    assert_nothing_raised do
      Name.send :delegate, :go, to: :_you, prefix: true
    end
    assert_raise(ArgumentError) do
      Name.send :delegate, :go, to: :You, prefix: true
    end
    assert_raise(ArgumentError) do
      Name.send :delegate, :go, to: :@you, prefix: true
    end
  end

  def test_delegation_prefix
    invoice = Invoice.new(@david)
    assert_equal "David", invoice.client_name
    assert_equal "Paulina", invoice.client_street
    assert_equal "Chicago", invoice.client_city
  end

  def test_delegation_custom_prefix
    invoice = Invoice.new(@david)
    assert_equal "David", invoice.customer_name
    assert_equal "Paulina", invoice.customer_street
    assert_equal "Chicago", invoice.customer_city
  end

  def test_delegation_prefix_with_nil_or_false
    assert_equal "David", Developer.new(@david).name
    assert_equal "David", Tester.new(@david).name
  end

  def test_delegation_prefix_with_instance_variable
    assert_raise ArgumentError do
      Class.new do
        def initialize(client)
          @client = client
        end
        delegate :name, :address, to: :@client, prefix: true
      end
    end
  end

  def test_delegation_with_allow_nil
    rails = Project.new("Rails", Someone.new("David"))
    assert_equal "David", rails.name
  end

  def test_delegation_with_allow_nil_and_nil_value
    rails = Project.new("Rails")
    assert_nil rails.name
  end

  # Ensures with check for nil, not for a falsy target.
  def test_delegation_with_allow_nil_and_false_value
    project = Project.new(false, false)
    assert_raise(NoMethodError) { project.name }
  end

  def test_delegation_with_allow_nil_and_invalid_value
    rails = Project.new("Rails", "David")
    assert_raise(NoMethodError) { rails.name }
  end

  def test_delegation_with_allow_nil_and_nil_value_and_prefix
    Project.class_eval do
      delegate :name, to: :person, allow_nil: true, prefix: true
    end
    rails = Project.new("Rails")
    assert_nil rails.person_name
  end

  def test_delegation_without_allow_nil_and_nil_value
    david = Someone.new("David")
    assert_raise(Module::DelegationError) { david.street }
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
          delegate :parent_method, to: :superclass
        end
      end
    end
  end

  def test_delegation_line_number
    _, line = Someone.instance_method(:foo).source_location
    assert_equal Someone::FAILED_DELEGATE_LINE, line
  end

  def test_delegate_line_with_nil
    _, line = Someone.instance_method(:bar).source_location
    assert_equal Someone::FAILED_DELEGATE_LINE_2, line
  end

  def test_delegation_exception_backtrace
    someone = Someone.new("foo", "bar")
    someone.foo
  rescue NoMethodError => e
    file_and_line = "#{__FILE__}:#{Someone::FAILED_DELEGATE_LINE}"
    # We can't simply check the first line of the backtrace, because JRuby reports the call to __send__ in the backtrace.
    assert e.backtrace.any? { |a| a.include?(file_and_line) },
           "[#{e.backtrace.inspect}] did not include [#{file_and_line}]"
  end

  def test_delegation_exception_backtrace_with_allow_nil
    someone = Someone.new("foo", "bar")
    someone.bar
  rescue NoMethodError => e
    file_and_line = "#{__FILE__}:#{Someone::FAILED_DELEGATE_LINE_2}"
    # We can't simply check the first line of the backtrace, because JRuby reports the call to __send__ in the backtrace.
    assert e.backtrace.any? { |a| a.include?(file_and_line) },
           "[#{e.backtrace.inspect}] did not include [#{file_and_line}]"
  end

  def test_delegation_invokes_the_target_exactly_once
    se = SideEffect.new

    assert_equal 1, se.to_i
    assert_equal [2, 3], se.ints

    assert_equal "2", se.to_s
    assert_equal [3], se.ints
  end

  def test_delegation_doesnt_mask_nested_no_method_error_on_nil_receiver
    product = Product.new("Widget")

    # Nested NoMethodError is a different name from the delegation
    assert_raise(NoMethodError) { product.manufacturer_name }

    # Nested NoMethodError is the same name as the delegation
    assert_raise(NoMethodError) { product.type_name }
  end

  def test_delegation_with_method_arguments
    has_block = HasBlock.new(Block.new)
    assert_predicate has_block, :hello?
  end

  def test_delegate_missing_to_with_method
    assert_equal "David", DecoratedTester.new(@david).name
  end

  def test_delegate_missing_to_with_reserved_methods
    assert_equal "David", DecoratedReserved.new(@david).name
  end

  def test_delegate_missing_to_with_keyword_methods
    assert_equal "David", DecoratedReserved.new(@david).kw_send(method: "name")
  end

  def test_delegate_missing_to_does_not_delegate_to_private_methods
    e = assert_raises(NoMethodError) do
      DecoratedReserved.new(@david).private_name
    end

    assert_match(/undefined method `private_name' for/, e.message)
  end

  def test_delegate_missing_to_does_not_delegate_to_fake_methods
    e = assert_raises(NoMethodError) do
      DecoratedReserved.new(@david).my_fake_method
    end

    assert_match(/undefined method `my_fake_method' for/, e.message)
  end

  def test_delegate_missing_to_raises_delegation_error_if_target_nil
    e = assert_raises(Module::DelegationError) do
      DecoratedTester.new(nil).name
    end

    assert_equal "name delegated to client, but client is nil", e.message
  end

  def test_delegate_missing_to_returns_nil_if_allow_nil_and_nil_target
    assert_nil DecoratedMissingAllowNil.new(nil).name
  end

  def test_delegate_missing_to_affects_respond_to
    assert_respond_to DecoratedTester.new(@david), :name
    assert_not_respond_to DecoratedTester.new(@david), :private_name
    assert_not_respond_to DecoratedTester.new(@david), :my_fake_method

    assert DecoratedTester.new(@david).respond_to?(:name, true)
    assert_not DecoratedTester.new(@david).respond_to?(:private_name, true)
    assert_not DecoratedTester.new(@david).respond_to?(:my_fake_method, true)
  end

  def test_delegate_missing_to_respects_superclass_missing
    assert_equal 42, DecoratedTester.new(@david).extra_missing

    assert_respond_to DecoratedTester.new(@david), :extra_missing
  end

  def test_delegate_missing_to_does_not_interfere_with_marshallization
    maze = Maze.new
    maze.cavern = Cavern.new(maze)

    array = [maze, nil]
    serialized_array = Marshal.dump(array)
    deserialized_array = Marshal.load(serialized_array)

    assert_nil deserialized_array[1]
  end

  def test_delegate_with_case
    event = Event.new(Tester.new)
    assert_equal 1, event.foo
  end

  def test_private_delegate
    location = Class.new do
      def initialize(place)
        @place = place
      end

      private(*delegate(:street, :city, to: :@place))
    end

    place = location.new(Somewhere.new("Such street", "Sad city"))

    assert_not_respond_to place, :street
    assert_not_respond_to place, :city

    assert place.respond_to?(:street, true) # Asking for private method
    assert place.respond_to?(:city, true)
  end

  def test_private_delegate_prefixed
    location = Class.new do
      def initialize(place)
        @place = place
      end

      private(*delegate(:street, :city, to: :@place, prefix: :the))
    end

    place = location.new(Somewhere.new("Such street", "Sad city"))

    assert_not_respond_to place, :street
    assert_not_respond_to place, :city

    assert_not_respond_to place, :the_street
    assert place.respond_to?(:the_street, true)
    assert_not_respond_to place, :the_city
    assert place.respond_to?(:the_city, true)
  end

  def test_private_delegate_with_private_option
    location = Class.new do
      def initialize(place)
        @place = place
      end

      delegate(:street, :city, to: :@place, private: true)
    end

    place = location.new(Somewhere.new("Such street", "Sad city"))

    assert_not_respond_to place, :street
    assert_not_respond_to place, :city

    assert place.respond_to?(:street, true) # Asking for private method
    assert place.respond_to?(:city, true)
  end

  def test_some_public_some_private_delegate_with_private_option
    location = Class.new do
      def initialize(place)
        @place = place
      end

      delegate(:street, to: :@place)
      delegate(:city, to: :@place, private: true)
    end

    place = location.new(Somewhere.new("Such street", "Sad city"))

    assert_respond_to place, :street
    assert_not_respond_to place, :city

    assert place.respond_to?(:city, true) # Asking for private method
  end

  def test_private_delegate_prefixed_with_private_option
    location = Class.new do
      def initialize(place)
        @place = place
      end

      delegate(:street, :city, to: :@place, prefix: :the, private: true)
    end

    place = location.new(Somewhere.new("Such street", "Sad city"))

    assert_not_respond_to place, :the_street
    assert place.respond_to?(:the_street, true)
    assert_not_respond_to place, :the_city
    assert place.respond_to?(:the_city, true)
  end

  def test_delegate_with_private_option_returns_names_of_delegate_methods
    location = Class.new do
      def initialize(place)
        @place = place
      end
    end

    assert_equal [:street, :city],
      location.delegate(:street, :city, to: :@place, private: true)

    assert_equal [:the_street, :the_city],
      location.delegate(:street, :city, to: :@place, prefix: :the, private: true)
  end
end
