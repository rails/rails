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

  def test_include?
    errors = ActiveModel::Errors.new(self)
    errors[:foo] = 'omg'
    assert errors.include?(:foo), 'errors should include :foo'
  end

  def test_has_key?
    errors = ActiveModel::Errors.new(self)
    errors[:foo] = 'omg'
    assert errors.has_key?(:foo), 'errors should have key :foo'
  end

  test "should return true if no errors" do
    person = Person.new
    person.errors[:foo]
    assert person.errors.empty?
    assert person.errors.blank?
    assert !person.errors.include?(:foo)
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

  test 'to_hash should return an ordered hash' do
    person = Person.new
    person.errors.add(:name, "can not be blank")
    assert_instance_of ActiveSupport::OrderedHash, person.errors.to_hash
  end

  test 'full_messages should return an array of error messages, with the attribute name included' do
    person = Person.new
    person.errors.add(:name, "can not be blank")
    person.errors.add(:name, "can not be nil")
    assert_equal ["name can not be blank", "name can not be nil"], person.errors.to_a
  end

  test 'full_message should return the given message if attribute equals :base' do
    person = Person.new
    assert_equal "press the button", person.errors.full_message(:base, "press the button")
  end

  test 'full_message should return the given message with the attribute name included' do
    person = Person.new
    assert_equal "name can not be blank", person.errors.full_message(:name, "can not be blank")
  end

  test 'should return a JSON hash representation of the errors' do
    person = Person.new
    person.errors.add(:name, "can not be blank")
    person.errors.add(:name, "can not be nil")
    person.errors.add(:email, "is invalid")
    hash = person.errors.as_json
    assert_equal ["can not be blank", "can not be nil"], hash[:name]
    assert_equal ["is invalid"], hash[:email]
  end

end

