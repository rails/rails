require "cases/helper"

class ErrorsTest < ActiveModel::TestCase
  class Person
    extend ActiveModel::Naming
    def initialize
      @errors = ActiveModel::Errors.new(self)
    end

    attr_accessor :name
    attr_reader   :errors

    def validate!
      errors.add(:name, "can not be nil") if name == nil
    end

    def read_attribute_for_validation(attr)
      send(attr)
    end

    def self.human_attribute_name(attr, options = {})
      attr
    end

    def self.lookup_ancestors
      [self]
    end

  end

  test "method validate! should work" do
    person = Person.new
    person.validate!
    assert_equal ["name can not be nil"], person.errors.full_messages
    assert_equal ["can not be nil"], person.errors[:name]

  end

  test 'should be able to assign error' do
    person = Person.new
    person.errors[:name] = 'should not be nil'
    assert_equal ["should not be nil"], person.errors[:name]
  end

  test 'should be able to add an error on an attribute' do
    person = Person.new
    person.errors.add(:name, "can not be blank")
    assert_equal ["can not be blank"], person.errors[:name]
  end

  test 'should respond to size' do
    person = Person.new
    person.errors.add(:name, "can not be blank")
    assert_equal 1, person.errors.size
  end

  test 'to_a should return an array' do
    person = Person.new
    person.errors.add(:name, "can not be blank")
    person.errors.add(:name, "can not be nil")
    assert_equal ["name can not be blank", "name can not be nil"], person.errors.to_a

  end

end
