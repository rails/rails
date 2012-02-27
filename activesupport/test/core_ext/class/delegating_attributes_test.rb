require 'abstract_unit'
require 'active_support/core_ext/class/delegating_attributes'

module DelegatingFixtures
  class Parent
  end

  class Child < Parent
    superclass_delegating_accessor :some_attribute
  end

  class Mokopuna < Child
  end

  class PercysMom
    superclass_delegating_accessor :superpower
  end

  class Percy < PercysMom
  end
end

class DelegatingAttributesTest < ActiveSupport::TestCase
  include DelegatingFixtures
  attr_reader :single_class

  def setup
    @single_class = Class.new(Object)
  end

  def test_simple_accessor_declaration
    single_class.superclass_delegating_accessor :both
    # Class should have accessor and mutator
    # the instance should have an accessor only
    assert_respond_to single_class, :both
    assert_respond_to single_class, :both=
    assert single_class.public_instance_methods.map(&:to_s).include?("both")
    assert !single_class.public_instance_methods.map(&:to_s).include?("both=")
  end

  def test_simple_accessor_declaration_with_instance_reader_false
    single_class.superclass_delegating_accessor :no_instance_reader, :instance_reader => false
    assert_respond_to single_class, :no_instance_reader
    assert_respond_to single_class, :no_instance_reader=
    assert !single_class.public_instance_methods.map(&:to_s).include?("no_instance_reader")
  end

  def test_working_with_simple_attributes
    single_class.superclass_delegating_accessor :both

    single_class.both = "HMMM"

    assert_equal "HMMM", single_class.both
    assert_equal true, single_class.both?

    assert_equal "HMMM", single_class.new.both
    assert_equal true, single_class.new.both?

    single_class.both = false
    assert_equal false, single_class.both?
  end

  def test_child_class_delegates_to_parent_but_can_be_overridden
    parent = Class.new
    parent.superclass_delegating_accessor :both
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
    assert_nil Percy.superpower
    assert_nil PercysMom.superpower

    PercysMom.superpower = :heatvision
    assert_equal :heatvision, Percy.superpower
  end

  def test_delegation_stops_for_nil
    Mokopuna.some_attribute = nil
    Child.some_attribute="1"

    assert_equal "1", Child.some_attribute
    assert_nil Mokopuna.some_attribute
  ensure
    Child.some_attribute=nil
  end

end
