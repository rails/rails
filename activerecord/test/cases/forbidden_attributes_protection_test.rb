require 'cases/helper'
require 'active_support/core_ext/hash/indifferent_access'
require 'models/person'

class ProtectedParams < ActiveSupport::HashWithIndifferentAccess
  attr_accessor :permitted
  alias :permitted? :permitted

  def initialize(attributes)
    super(attributes)
    @permitted = false
  end

  def permit!
    @permitted = true
    self
  end

  def dup
    super.tap do |duplicate|
      duplicate.instance_variable_set :@permitted, @permitted
    end
  end
end

class ForbiddenAttributesProtectionTest < ActiveRecord::TestCase
  def test_forbidden_attributes_cannot_be_used_for_mass_assignment
    params = ProtectedParams.new(first_name: 'Guille', gender: 'm')
    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Person.new(params)
    end
  end

  def test_permitted_attributes_can_be_used_for_mass_assignment
    params = ProtectedParams.new(first_name: 'Guille', gender: 'm')
    params.permit!
    person = Person.new(params)

    assert_equal 'Guille', person.first_name
    assert_equal 'm', person.gender
  end

  def test_regular_hash_should_still_be_used_for_mass_assignment
    person = Person.new(first_name: 'Guille', gender: 'm')

    assert_equal 'Guille', person.first_name
    assert_equal 'm', person.gender
  end
end
