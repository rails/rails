# frozen_string_literal: true

require "cases/helper"

class MultiparameterAttributeAssignmentTest < ActiveModel::TestCase
  class Address < Struct.new(:street, :city, :country) ; end

  class AddressType < ActiveModel::Type::Value
    def cast(hash_values)
      Address.new(*hash_values.sort.map(&:last))
    end
  end

  class Person
    include ActiveModel::Attributes
    include ActiveModel::MultiparameterAttributeAssignment
    attribute :name, :string
    attribute :date_of_birth, :date
    attribute :last_slept, :datetime
    attribute :address, AddressType.new
  end

  def setup
    Time.zone = "UTC"
  end

  def test_multiparameter_attributes_on_date
    person = Person.new
    person.attributes = {
      "date_of_birth(1i)" => "2004",
      "date_of_birth(2i)" => "6",
      "date_of_birth(3i)" => "24"
    }
    assert_equal Date.new(2004, 6, 24), person.date_of_birth
  end

  def test_multiparameter_attributes_on_date_with_empty_year
    person = Person.new
    person.attributes = {
      "date_of_birth(1i)" => "",
      "date_of_birth(2i)" => "6",
      "date_of_birth(3i)" => "24"
    }
    assert_nil person.date_of_birth
  end

  def test_multiparameter_attributes_on_date_with_empty_month
    person = Person.new
    person.attributes = {
      "date_of_birth(1i)" => "2004",
      "date_of_birth(2i)" => "",
      "date_of_birth(3i)" => "24"
    }
    assert_nil person.date_of_birth
  end

  def test_multiparameter_attributes_on_date_with_empty_day
    person = Person.new
    person.attributes = {
      "date_of_birth(1i)" => "2004",
      "date_of_birth(2i)" => "6",
      "date_of_birth(3i)" => ""
    }
    assert_nil person.date_of_birth
  end

  def test_multiparameter_attributes_on_date_with_empty_day_and_year
    person = Person.new
    person.attributes = {
      "date_of_birth(1i)" => "",
      "date_of_birth(2i)" => "6",
      "date_of_birth(3i)" => ""
    }
    assert_nil person.date_of_birth
  end

  def test_multiparameter_attributes_on_date_with_empty_day_and_month
    person = Person.new
    person.attributes = {
      "date_of_birth(1i)" => "2004",
      "date_of_birth(2i)" => "",
      "date_of_birth(3i)" => ""
    }
    assert_nil person.date_of_birth
  end

  def test_multiparameter_attributes_on_date_with_empty_year_and_month
    person = Person.new
    person.attributes = {
      "date_of_birth(1i)" => "",
      "date_of_birth(2i)" => "",
      "date_of_birth(3i)" => "24"
    }
    assert_nil person.date_of_birth
  end

  def test_multiparameter_attributes_on_date_with_all_empty
    person = Person.new
    person.attributes = {
      "date_of_birth(1i)" => "",
      "date_of_birth(2i)" => "",
      "date_of_birth(3i)" => ""
    }
    assert_nil person.date_of_birth
  end

  def test_multiparameter_attributes_on_time
    person = Person.new
    person.attributes = {
      "last_slept(1i)" => "2004", "last_slept(2i)" => "6", "last_slept(3i)" => "24",
      "last_slept(4i)" => "16", "last_slept(5i)" => "24", "last_slept(6i)" => "00"
    }
    assert_equal Time.zone.local(2004, 6, 24, 16, 24, 0), person.last_slept
  end

  def test_multiparameter_attributes_on_time_with_no_date
    person = Person.new
    ex = assert_raise(ActiveModel::MultiparameterAssignmentErrors) do
      person.attributes = {
        "last_slept(4i)" => "16",
        "last_slept(5i)" => "24",
        "last_slept(6i)" => "00"
      }
    end
    assert_equal("last_slept", ex.errors[0].attribute)
  end

  def test_multiparameter_attributes_on_time_with_invalid_time_params
    person = Person.new
    ex = assert_raise(ActiveModel::MultiparameterAssignmentErrors) do
      person.attributes = {
        "last_slept(1i)" => "2004",
        "last_slept(2i)" => "6",
        "last_slept(3i)" => "24",
        "last_slept(4i)" => "2004",
        "last_slept(5i)" => "36",
        "last_slept(6i)" => "64",
      }
    end
    assert_equal("last_slept", ex.errors[0].attribute)
  end

  def test_multiparameter_attributes_on_time_with_old_date
    person = Person.new
    person.attributes = {
      "last_slept(1i)" => "1850",
      "last_slept(2i)" => "6",
      "last_slept(3i)" => "24",
      "last_slept(4i)" => "16",
      "last_slept(5i)" => "24",
      "last_slept(6i)" => "00"
    }
    assert_equal Time.zone.local(1850, 6, 24, 16, 24, 0), person.last_slept
  end

  def test_multiparameter_attributes_on_time_will_raise_on_big_time_if_missing_date_parts
    person = Person.new
    ex = assert_raise(ActiveModel::MultiparameterAssignmentErrors) do
      person.attributes = {
        "last_slept(4i)" => "16", "last_slept(5i)" => "24"
      }
    end
    assert_equal("last_slept", ex.errors[0].attribute)
  end

  def test_multiparameter_attributes_on_time_with_raise_on_small_time_if_missing_date_parts
    person = Person.new
    ex = assert_raise(ActiveModel::MultiparameterAssignmentErrors) do
      person.attributes = {
        "last_slept(4i)" => "16",
        "last_slept(5i)" => "12",
        "last_slept(6i)" => "02"
      }
    end
    assert_equal("last_slept", ex.errors[0].attribute)
  end

  def test_multiparameter_attributes_on_time_will_ignore_hour_if_missing
    person = Person.new
    person.attributes = {
      "last_slept(1i)" => "2004", "last_slept(2i)" => "12", "last_slept(3i)" => "12",
      "last_slept(5i)" => "12", "last_slept(6i)" => "02"
    }
    assert_equal Time.zone.local(2004, 12, 12, 0, 12, 2), person.last_slept
  end

  def test_multiparameter_attributes_on_time_will_ignore_hour_if_blank
    person = Person.new
    person.attributes = {
      "last_slept(1i)" => "", "last_slept(2i)" => "", "last_slept(3i)" => "",
      "last_slept(4i)" => "", "last_slept(5i)" => "12", "last_slept(6i)" => "02"
    }
    assert_nil person.last_slept
  end

  def test_multiparameter_attributes_on_time_will_ignore_date_if_empty
    person = Person.new
    person.attributes = {
      "last_slept(1i)" => "", "last_slept(2i)" => "", "last_slept(3i)" => "",
      "last_slept(4i)" => "16", "last_slept(5i)" => "24"
    }
    assert_nil person.last_slept
  end

  def test_multiparameter_attributes_on_time_with_seconds_will_ignore_date_if_empty
    person = Person.new
    person.attributes = {
      "last_slept(1i)" => "", "last_slept(2i)" => "", "last_slept(3i)" => "",
      "last_slept(4i)" => "16", "last_slept(5i)" => "12", "last_slept(6i)" => "02"
    }
    assert_nil person.last_slept
  end

  def test_multiparameter_attributes_on_time_with_empty_seconds
    person = Person.new
    person.attributes = {
      "last_slept(1i)" => "2004", "last_slept(2i)" => "6", "last_slept(3i)" => "24",
      "last_slept(4i)" => "16", "last_slept(5i)" => "24", "last_slept(6i)" => ""
    }
    assert_equal Time.zone.local(2004, 6, 24, 16, 24, 0), person.last_slept
  end

  def test_multiparameter_attributes_setting_date_attribute
    person = Person.new
    person.attributes = { "last_slept(1i)" => "1952", "last_slept(2i)" => "3", "last_slept(3i)" => "11" }
    assert_equal 1952, person.last_slept.year
    assert_equal 3, person.last_slept.month
    assert_equal 11, person.last_slept.day
  end

  def test_multiparameter_attributes_setting_date_and_time_attribute
    person = Person.new
    person.attributes = {
      "last_slept(1i)" => "1952",
      "last_slept(2i)" => "3",
      "last_slept(3i)" => "11",
      "last_slept(4i)" => "13",
      "last_slept(5i)" => "55"
    }
    assert_equal 1952, person.last_slept.year
    assert_equal 3, person.last_slept.month
    assert_equal 11, person.last_slept.day
    assert_equal 13, person.last_slept.hour
    assert_equal 55, person.last_slept.min
  end

  def test_multiparameter_attributes_setting_time_but_not_date_on_date_field
    person = Person.new
    assert_raise(ActiveModel::MultiparameterAssignmentErrors) do
      person.attributes = { "last_slept(4i)" => "13", "last_slept(5i)" => "55" }
    end
  end

  def test_multiparameter_assignment_of_custom_attribute_type
    address = Address.new("The Street", "The City", "The Country")
    person = Person.new
    person.attributes = {
      "address(1)" => address.street,
      "address(2)" => address.city,
      "address(3)" => address.country
    }
    assert_equal address, person.address
  end
end
