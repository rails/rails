require "cases/helper"
require 'models/company'
require 'models/subscriber'
require 'models/keyboard'
require 'models/task'

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

  def test_protection_against_class_attribute_writers
    [:logger, :configurations, :primary_key_prefix_type, :table_name_prefix, :table_name_suffix, :pluralize_table_names,
     :default_timezone, :schema_format, :lock_optimistically, :record_timestamps].each do |method|
      assert_respond_to  Task, method
      assert_respond_to  Task, "#{method}="
      assert_respond_to  Task.new, method
      assert !Task.new.respond_to?("#{method}=")
    end
  end

end
