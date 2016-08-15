require "cases/helper"
require "active_support/core_ext/hash/indifferent_access"

require "models/company"
require "models/person"
require "models/ship"
require "models/ship_part"
require "models/treasure"

class ProtectedParams
  attr_accessor :permitted
  alias :permitted? :permitted

  delegate :keys, :key?, :has_key?, :empty?, to: :@parameters

  def initialize(attributes)
    @parameters = attributes.with_indifferent_access
    @permitted = false
  end

  def permit!
    @permitted = true
    self
  end

  def [](key)
    @parameters[key]
  end

  def to_h
    @parameters
  end

  def stringify_keys
    dup
  end

  def dup
    super.tap do |duplicate|
      duplicate.instance_variable_set :@permitted, @permitted
    end
  end
end

class ForbiddenAttributesProtectionTest < ActiveRecord::TestCase
  def test_forbidden_attributes_cannot_be_used_for_mass_assignment
    params = ProtectedParams.new(first_name: "Guille", gender: "m")
    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Person.new(params)
    end
  end

  def test_permitted_attributes_can_be_used_for_mass_assignment
    params = ProtectedParams.new(first_name: "Guille", gender: "m")
    params.permit!
    person = Person.new(params)

    assert_equal "Guille", person.first_name
    assert_equal "m", person.gender
  end

  def test_forbidden_attributes_cannot_be_used_for_sti_inheritance_column
    params = ProtectedParams.new(type: "Client")
    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Company.new(params)
    end
  end

  def test_permitted_attributes_can_be_used_for_sti_inheritance_column
    params = ProtectedParams.new(type: "Client")
    params.permit!
    person = Company.new(params)
    assert_equal person.class, Client
  end

  def test_regular_hash_should_still_be_used_for_mass_assignment
    person = Person.new(first_name: "Guille", gender: "m")

    assert_equal "Guille", person.first_name
    assert_equal "m", person.gender
  end

  def test_blank_attributes_should_not_raise
    person = Person.new
    assert_nil person.assign_attributes(ProtectedParams.new({}))
  end

  def test_create_with_checks_permitted
    params = ProtectedParams.new(first_name: "Guille", gender: "m")

    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Person.create_with(params).create!
    end
  end

  def test_create_with_works_with_permitted_params
    params = ProtectedParams.new(first_name: "Guille").permit!

    person = Person.create_with(params).create!
    assert_equal "Guille", person.first_name
  end

  def test_create_with_works_with_params_values
    params = ProtectedParams.new(first_name: "Guille")

    person = Person.create_with(first_name: params[:first_name]).create!
    assert_equal "Guille", person.first_name
  end

  def test_where_checks_permitted
    params = ProtectedParams.new(first_name: "Guille", gender: "m")

    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Person.where(params).create!
    end
  end

  def test_where_works_with_permitted_params
    params = ProtectedParams.new(first_name: "Guille").permit!

    person = Person.where(params).create!
    assert_equal "Guille", person.first_name
  end

  def test_where_works_with_params_values
    params = ProtectedParams.new(first_name: "Guille")

    person = Person.where(first_name: params[:first_name]).create!
    assert_equal "Guille", person.first_name
  end

  def test_where_not_checks_permitted
    params = ProtectedParams.new(first_name: "Guille", gender: "m")

    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Person.where().not(params)
    end
  end

  def test_where_not_works_with_permitted_params
    params = ProtectedParams.new(first_name: "Guille").permit!
    Person.create!(params)
    assert_empty Person.where.not(params).select {|p| p.first_name == "Guille" }
  end

  def test_strong_params_style_objects_work_with_singular_associations
    params = ProtectedParams.new( name: "Stern", ship_attributes: ProtectedParams.new(name: "The Black Rock").permit!).permit!
    part = ShipPart.new(params)

    assert_equal "Stern", part.name
    assert_equal "The Black Rock", part.ship.name
  end

  def test_strong_params_style_objects_work_with_collection_associations
    params = ProtectedParams.new(
      trinkets_attributes: ProtectedParams.new(
        "0" => ProtectedParams.new(name: "Necklace").permit!,
        "1" => ProtectedParams.new(name: "Spoon").permit! ) ).permit!
    part = ShipPart.new(params)

    assert_equal "Necklace", part.trinkets[0].name
    assert_equal "Spoon", part.trinkets[1].name
  end
end
