require 'cases/helper'

# Stub out an AR-alike.
class DirtyTestSubject
  def self.table_name;  'people' end
  def self.primary_key; 'id' end
  def self.attribute_method_suffix(*suffixes) suffixes end

  def initialize(attrs = {}) @attributes = attrs end

  def save
    changed_attributes.clear
  end

  alias_method :save!, :save

  def name; read_attribute('name') end
  def name=(value); write_attribute('name', value) end
  def name_was; attribute_was('name') end
  def name_change; attribute_change('name') end
  def name_changed?; attribute_changed?('name') end

  private
    def define_read_methods; nil end

    def read_attribute(attr)
      @attributes[attr]
    end

    def write_attribute(attr, value)
      @attributes[attr] = value
    end
end

# Include the module after the class is all set up.
DirtyTestSubject.module_eval { include ActiveRecord::Dirty }


class DirtyTest < Test::Unit::TestCase
  def test_attribute_changes
    # New record - no changes.
    person = DirtyTestSubject.new
    assert !person.name_changed?
    assert_nil person.name_change

    # Change name.
    person.name = 'a'
    assert person.name_changed?
    assert_nil person.name_was
    assert_equal [nil, 'a'], person.name_change

    # Saved - no changes.
    person.save!
    assert !person.name_changed?
    assert_nil person.name_change

    # Same value - no changes.
    person.name = 'a'
    assert !person.name_changed?
    assert_nil person.name_change
  end

  def test_object_should_be_changed_if_any_attribute_is_changed
    person = DirtyTestSubject.new
    assert !person.changed?
    assert_equal [], person.changed
    assert_equal Hash.new, person.changes

    person.name = 'a'
    assert person.changed?
    assert_nil person.name_was
    assert_equal %w(name), person.changed
    assert_equal({'name' => [nil, 'a']}, person.changes)

    person.save
    assert !person.changed?
    assert_equal [], person.changed
    assert_equal({}, person.changes)
  end
end
