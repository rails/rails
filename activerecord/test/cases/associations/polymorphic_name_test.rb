require 'cases/helper'
require 'models/legacy_thing'
require 'models/reference'

class PolymorphicNameTest < ActiveRecord::TestCase
  fixtures :legacy_things, :references

  setup do
    ActiveRecord::Base.derive_class_name_for_association_reflection = Proc.new do |name|
      class_name = name.to_s
      class_name = class_name.singularize if collection?
      class_name.camelize
    end
  end

  teardown do
    ActiveRecord::Base.derive_class_name_for_association_reflection = false
  end

  def test_belongs_to
    thing = LegacyThing.find(2)
    assert_equal 'reference', thing.resource_type
    assert_equal 1, thing.resource_id.to_i
    resource = thing.resource
    assert_equal 1, resource.id
    assert_equal Reference, resource.class
  end

  def test_has_many
    ref = Reference.find(1)
    assert_equal 1, ref.legacy_things.count
    assert_equal 2, ref.legacy_things.first.id
  end

  def test_joins
    ref = Reference.joins(:legacy_things).select('legacy_things.id AS legacy_thing_id').where(id: 1).first
    assert_equal 2, ref[:legacy_thing_id]
  end

  def test_replace
    thing = LegacyThing.find(2)
    ref = Reference.find(3)
    thing.resource = ref
    assert_equal 3, thing.resource.id
  end

end
