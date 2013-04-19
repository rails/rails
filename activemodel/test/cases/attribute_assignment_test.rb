require 'cases/helper'

class AttributeAssignmentTest < ActiveModel::TestCase
  class Person
    include ActiveModel::Model
    include ActiveModel::AttributeAssignment
    attr_accessor :name, :address

    def class_for_attribute(attr)
      if attr == 'address'
        Address
      end
    end
  end

  class Address < Struct.new(:street, :city, :country)
  end

  def test_initialize_with_complete_multiparameter_value
    person = Person.new(
      'name' => 'John Doe',
      'address' => Address.new('123 Some Street', 'The City', 'The Country')
    )

    assert_equal 'John Doe', person.name
    assert_equal '123 Some Street', person.address.street
    assert_equal 'The City', person.address.city
    assert_equal 'The Country', person.address.country
  end

  def test_initialize_with_parts_of_multiparameter_value
    person = Person.new(
      'name' => 'John Doe',
      'address(1)' => '123 Some Street',
      'address(2)' => 'The City',
      'address(3)' => 'The Country'
    )

    assert_equal 'John Doe', person.name
    assert_equal '123 Some Street', person.address.street
    assert_equal 'The City', person.address.city
    assert_equal 'The Country', person.address.country
  end
end
