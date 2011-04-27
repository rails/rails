require "cases/helper"
require 'models/company'
require 'models/subscriber'
require 'models/keyboard'
require 'models/task'
require 'models/person'

class MassAssignmentSecurityTest < ActiveRecord::TestCase

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

  def test_assign_attributes_uses_default_scope_when_no_scope_is_provided
    p = LoosePerson.new
    p.assign_attributes(attributes_hash)

    assert_equal nil,    p.id
    assert_equal 'Josh', p.first_name
    assert_equal 'm',    p.gender
    assert_equal nil,    p.comments
  end

  def test_assign_attributes_skips_mass_assignment_security_protection_when_without_protection_is_used
    p = LoosePerson.new
    p.assign_attributes(attributes_hash, :without_protection => true)

    assert_equal 5, p.id
    assert_equal 'Josh', p.first_name
    assert_equal 'm', p.gender
    assert_equal 'rides a sweet bike', p.comments
  end

  def test_assign_attributes_with_default_scope_and_attr_protected_attributes
    p = LoosePerson.new
    p.assign_attributes(attributes_hash, :as => :default)

    assert_equal nil, p.id
    assert_equal 'Josh', p.first_name
    assert_equal 'm', p.gender
    assert_equal nil, p.comments
  end

  def test_assign_attributes_with_admin_scope_and_attr_protected_attributes
    p = LoosePerson.new
    p.assign_attributes(attributes_hash, :as => :admin)

    assert_equal nil, p.id
    assert_equal 'Josh', p.first_name
    assert_equal 'm', p.gender
    assert_equal 'rides a sweet bike', p.comments
  end

  def test_assign_attributes_with_default_scope_and_attr_accessible_attributes
    p = TightPerson.new
    p.assign_attributes(attributes_hash, :as => :default)

    assert_equal nil, p.id
    assert_equal 'Josh', p.first_name
    assert_equal 'm', p.gender
    assert_equal nil, p.comments
  end

  def test_assign_attributes_with_admin_scope_and_attr_accessible_attributes
    p = TightPerson.new
    p.assign_attributes(attributes_hash, :as => :admin)

    assert_equal nil, p.id
    assert_equal 'Josh', p.first_name
    assert_equal 'm', p.gender
    assert_equal 'rides a sweet bike', p.comments
  end

  def test_protection_against_class_attribute_writers
    [:logger, :configurations, :primary_key_prefix_type, :table_name_prefix, :table_name_suffix, :pluralize_table_names,
     :default_timezone, :schema_format, :lock_optimistically, :record_timestamps].each do |method|
      assert_respond_to  Task, method
      assert_respond_to  Task, "#{method}="
      assert_respond_to  Task.new, method
      assert !Task.new.respond_to?("#{method}=")
    end
  end

  private

  def attributes_hash
    {
      :id => 5,
      :first_name => 'Josh',
      :gender   => 'm',
      :comments => 'rides a sweet bike'
    }
  end
end