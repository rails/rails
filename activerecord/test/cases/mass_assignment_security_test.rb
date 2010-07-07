require "cases/helper"
require 'models/reply'
require 'models/company'
require 'models/subscriber'
require 'models/keyboard'
require 'models/mass_assignment_specific'

class MassAssignmentSecurityTest < ActiveRecord::TestCase

  def test_mass_assignment_protection
    firm = Firm.new
    firm.attributes = { "name" => "Next Angle", "rating" => 5 }
    assert_equal 1, firm.rating
  end

  def test_mass_assignment_protection_against_class_attribute_writers
    [:logger, :configurations, :primary_key_prefix_type, :table_name_prefix, :table_name_suffix, :pluralize_table_names,
     :default_timezone, :schema_format, :lock_optimistically, :record_timestamps].each do |method|
      assert_respond_to  Task, method
      assert_respond_to  Task, "#{method}="
      assert_respond_to  Task.new, method
      assert !Task.new.respond_to?("#{method}=")
    end
  end

  def test_customized_primary_key_remains_protected
    subscriber = Subscriber.new(:nick => 'webster123', :name => 'nice try')
    assert_nil subscriber.id

    keyboard = Keyboard.new(:key_number => 9, :name => 'nice try')
    assert_nil keyboard.id
  end

  def test_customized_primary_key_remains_protected_when_referred_to_as_id
    subscriber = Subscriber.new(:id => 'webster123', :name => 'nice try')
    assert_nil subscriber.id

    keyboard = Keyboard.new(:id => 9, :name => 'nice try')
    assert_nil keyboard.id
  end

  def test_mass_assigning_invalid_attribute
    firm = Firm.new

    assert_raise(ActiveRecord::UnknownAttributeError) do
      firm.attributes = { "id" => 5, "type" => "Client", "i_dont_even_exist" => 20 }
    end
  end

  def test_mass_assignment_protection_on_defaults
    firm = Firm.new
    firm.attributes = { "id" => 5, "type" => "Client" }
    assert_nil firm.id
    assert_equal "Firm", firm[:type]
  end

  def test_mass_assignment_accessible
    reply = Reply.new("title" => "hello", "content" => "world", "approved" => true)
    reply.save

    assert reply.approved?

    reply.approved = false
    reply.save

    assert !reply.approved?
  end

  def test_mass_assignment_protection_inheritance
    assert LoosePerson.accessible_attributes.blank?
    assert_equal Set.new([ 'credit_rating', 'administrator', *LoosePerson.attributes_protected_by_default ]), LoosePerson.protected_attributes

    assert LooseDescendant.accessible_attributes.blank?
    assert_equal Set.new([ 'credit_rating', 'administrator', 'phone_number', *LoosePerson.attributes_protected_by_default ]), LooseDescendant.protected_attributes

    assert LooseDescendantSecond.accessible_attributes.blank?
    assert_equal Set.new([ 'credit_rating', 'administrator', 'phone_number', 'name', *LoosePerson.attributes_protected_by_default ]),
      LooseDescendantSecond.protected_attributes, 'Running attr_protected twice in one class should merge the protections'

    assert (TightPerson.protected_attributes - TightPerson.attributes_protected_by_default).blank?
    assert_equal Set.new([ 'name', 'address' ]), TightPerson.accessible_attributes

    assert (TightDescendant.protected_attributes - TightDescendant.attributes_protected_by_default).blank?
    assert_equal Set.new([ 'name', 'address', 'phone_number' ]), TightDescendant.accessible_attributes
  end

  def test_mass_assignment_multiparameter_protector
    task = Task.new
    time = Time.mktime(2000, 1, 1, 1)
    task.starting = time
    attributes = { "starting(1i)" => "2004", "starting(2i)" => "6", "starting(3i)" => "24" }
    task.attributes = attributes
    assert_equal time, task.starting
  end

end