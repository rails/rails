require 'abstract_unit'

module DelegatingFixtures
  class Parent
  end

  class Child < Parent
    class_attribute :some_attribute
  end

  class Mokopuna < Child
  end
end

class DelegatingAttributesTest < Test::Unit::TestCase
  include DelegatingFixtures
  attr_reader :single_class

  def setup
    @single_class = Class.new(Object)
  end

  def test_simple_reader_declaration
    single_class.superclass_delegating_reader   :only_reader
    # The class and instance should have an accessor, but there
    # should be no mutator
    assert single_class.respond_to?(:only_reader)
    assert single_class.respond_to?(:only_reader?)
    assert single_class.public_instance_methods.map(&:to_s).include?("only_reader")
    assert single_class.public_instance_methods.map(&:to_s).include?("only_reader?")
    assert !single_class.respond_to?(:only_reader=)
  end

  def test_simple_writer_declaration
    single_class.superclass_delegating_writer   :only_writer
    # The class should have a mutator, the instances shouldn't
    # neither should have an accessor
    assert single_class.respond_to?(:only_writer=)
    assert !single_class.public_instance_methods.include?("only_writer=")
    assert !single_class.public_instance_methods.include?("only_writer")
    assert !single_class.respond_to?(:only_writer)
  end

  def test_simple_accessor_declaration
    single_class.class_attribute :both, :instance_writer => false
    # Class should have accessor and mutator
    # the instance should have an accessor only
    assert single_class.respond_to?(:both)
    assert single_class.respond_to?(:both=)
    assert single_class.public_instance_methods.map(&:to_s).include?("both")
    assert !single_class.public_instance_methods.map(&:to_s).include?("both=")
  end

  def test_working_with_simple_attributes
    single_class.class_attribute :both

    single_class.both = "HMMM"

    assert_equal "HMMM", single_class.both
    assert_equal true, single_class.both?

    assert_equal "HMMM", single_class.new.both
    assert_equal true, single_class.new.both?

    single_class.both = false
    assert_equal false, single_class.both?
  end

  def test_working_with_accessors
    single_class.superclass_delegating_reader   :only_reader
    single_class.instance_variable_set("@only_reader", "reading only")
    assert_equal "reading only", single_class.only_reader
    assert_equal "reading only", single_class.new.only_reader
  end

  def test_working_with_simple_mutators
    single_class.superclass_delegating_writer   :only_writer
    single_class.only_writer="written"
    assert_equal "written", single_class.instance_variable_get("@only_writer")
  end

  def test_child_class_delegates_to_parent_but_can_be_overridden
    parent = Class.new
    parent.class_attribute :both
    child = Class.new(parent)
    parent.both = "1"
    assert_equal "1", child.both

    child.both = "2"
    assert_equal "1", parent.both
    assert_equal "2", child.both

    parent.both = "3"
    assert_equal "3", parent.both
    assert_equal "2", child.both
  end

  def test_delegation_stops_at_the_right_level
    assert_nil Mokopuna.some_attribute
    assert_nil Child.some_attribute
    Child.some_attribute="1"
    assert_equal "1", Mokopuna.some_attribute
  ensure
    Child.some_attribute=nil
  end
  
  def test_delegation_stops_for_nil
    Mokopuna.some_attribute = nil
    Child.some_attribute="1"
    
    assert_equal "1", Child.some_attribute
    assert_nil Mokopuna.some_attribute
  end

end
