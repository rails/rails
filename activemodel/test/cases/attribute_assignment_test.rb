require 'cases/helper'
require 'active_support/hash_with_indifferent_access' 

class AttributeAssignmentTest < ActiveModel::TestCase

  class Model
    include ActiveModel::AttributeAssignment

    attr_accessor :name, :description

    def initialize(attributes = {})
      assign_attributes(attributes)
    end

    def broken_attribute=(value)
      non_existing_method(value)
    end

    private
    def metadata=(data)
      @metadata = data
    end
  end

  class ProtectedParams < ActiveSupport::HashWithIndifferentAccess
    def permit!
      @permitted = true
    end

    def permitted?
      @permitted ||= false
    end

    def dup
      super.tap do |duplicate|
        duplicate.instance_variable_set :@permitted, permitted?
      end
    end
  end

  test "simple assignment" do
    model = Model.new

    model.assign_attributes(name: 'hello', description: 'world')
    assert_equal 'hello', model.name
    assert_equal 'world', model.description
  end

  test "assign non-existing attribute" do
    model = Model.new
    error = assert_raises ActiveModel::AttributeAssignment::UnknownAttributeError do
      model.assign_attributes(hz: 1)
    end

    assert_equal model, error.record
    assert_equal "hz", error.attribute
  end

  test "assign private attribute" do
    model = Model.new
    assert_raises ActiveModel::AttributeAssignment::UnknownAttributeError do
      model.assign_attributes(metadata: { a: 1 })
    end
  end

  test "raises NoMethodError if raised in attribute writer" do
    assert_raises NoMethodError do
      Model.new(broken_attribute: 1)
    end
  end

  test "raises ArgumentError if non-hash object passed" do
    assert_raises ArgumentError do
      Model.new(1)
    end
  end

  test 'forbidden attributes cannot be used for mass assignment' do
    params = ProtectedParams.new(name: 'Guille', description: 'm')
    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Model.new(params)
    end
  end

  test 'permitted attributes can be used for mass assignment' do
    params = ProtectedParams.new(name: 'Guille', description: 'desc')
    params.permit!
    model = Model.new(params)

    assert_equal 'Guille', model.name
    assert_equal 'desc', model.description
  end

  test 'regular hash should still be used for mass assignment' do
    model = Model.new(name: 'Guille', description: 'm')

    assert_equal 'Guille', model.name
    assert_equal 'm', model.description
  end

  test 'blank attributes should not raise' do
    model = Model.new
    assert_nil model.assign_attributes(ProtectedParams.new({}))
  end

end
