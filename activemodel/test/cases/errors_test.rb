require "cases/helper"

class ErrorsTest < ActiveModel::TestCase
  class Person
    extend ActiveModel::Naming
    def initialize
      @errors = ActiveModel::Errors.new(self)
    end

    attr_accessor :name, :age
    attr_reader   :errors

    def validate!
      errors.add(:name, :blank, message: "cannot be nil") if name == nil
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

  def test_delete
    errors = ActiveModel::Errors.new(self)
    errors[:foo] << 'omg'
    errors.delete(:foo)
    assert_empty errors[:foo]
  end

  def test_include?
    errors = ActiveModel::Errors.new(self)
    errors[:foo] << 'omg'
    assert errors.include?(:foo), 'errors should include :foo'
  end

  def test_dup
    errors = ActiveModel::Errors.new(self)
    errors[:foo] << 'bar'
    errors_dup = errors.dup
    errors_dup[:bar] << 'omg'
    assert_not_same errors_dup.messages, errors.messages
  end

  def test_has_key?
    errors = ActiveModel::Errors.new(self)
    errors[:foo] << 'omg'
    assert_equal true, errors.has_key?(:foo), 'errors should have key :foo'
  end

  def test_has_no_key
    errors = ActiveModel::Errors.new(self)
    assert_equal false, errors.has_key?(:name), 'errors should not have key :name'
  end

  def test_key?
    errors = ActiveModel::Errors.new(self)
    errors[:foo] << 'omg'
    assert_equal true, errors.key?(:foo), 'errors should have key :foo'
  end

  def test_no_key
    errors = ActiveModel::Errors.new(self)
    assert_equal false, errors.key?(:name), 'errors should not have key :name'
  end

  test "clear errors" do
    person = Person.new
    person.validate!

    assert_equal 1, person.errors.count
    person.errors.clear
    assert person.errors.empty?
  end

  test "get returns the errors for the provided key" do
    errors = ActiveModel::Errors.new(self)
    errors[:foo] << "omg"

    assert_deprecated do
      assert_equal ["omg"], errors.get(:foo)
    end
  end

  test "sets the error with the provided key" do
    errors = ActiveModel::Errors.new(self)
    assert_deprecated do
      errors.set(:foo, "omg")
    end

    assert_equal({ foo: "omg" }, errors.messages)
  end

  test "error access is indifferent" do
    errors = ActiveModel::Errors.new(self)
    errors[:foo] << "omg"

    assert_equal ["omg"], errors["foo"]
  end

  test "values returns an array of messages" do
    errors = ActiveModel::Errors.new(self)
    errors.messages[:foo] = "omg"
    errors.messages[:baz] = "zomg"

    assert_equal ["omg", "zomg"], errors.values
  end

  test "keys returns the error keys" do
    errors = ActiveModel::Errors.new(self)
    errors.messages[:foo] << "omg"
    errors.messages[:baz] << "zomg"

    assert_equal [:foo, :baz], errors.keys
  end

  test "detecting whether there are errors with empty?, blank?, include?" do
    person = Person.new
    person.errors[:foo]
    assert person.errors.empty?
    assert person.errors.blank?
    assert !person.errors.include?(:foo)
  end

  test "include? does not add a key to messages hash" do
    person = Person.new
    person.errors.include?(:foo)

    assert_not person.errors.messages.key?(:foo)
  end

  test "adding errors using conditionals with Person#validate!" do
    person = Person.new
    person.validate!
    assert_equal ["name cannot be nil"], person.errors.full_messages
    assert_equal ["cannot be nil"], person.errors[:name]
  end

  test "assign error" do
    person = Person.new
    assert_deprecated do
      person.errors[:name] = 'should not be nil'
    end
    assert_equal ["should not be nil"], person.errors[:name]
  end

  test "add an error message on a specific attribute" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    assert_equal ["cannot be blank"], person.errors[:name]
  end

  test "add an error message on a specific attribute with a defined type" do
    person = Person.new
    person.errors.add(:name, :blank, message: "cannot be blank")
    assert_equal ["cannot be blank"], person.errors[:name]
  end

  test "add an error with a symbol" do
    person = Person.new
    person.errors.add(:name, :blank)
    message = person.errors.generate_message(:name, :blank)
    assert_equal [message], person.errors[:name]
  end

  test "add an error with a proc" do
    person = Person.new
    message = Proc.new { "cannot be blank" }
    person.errors.add(:name, message)
    assert_equal ["cannot be blank"], person.errors[:name]
  end

  test "added? detects if a specific error was added to the object" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    assert person.errors.added?(:name, "cannot be blank")
  end

  test "added? handles symbol message" do
    person = Person.new
    person.errors.add(:name, :blank)
    assert person.errors.added?(:name, :blank)
  end

  test "added? handles proc messages" do
    person = Person.new
    message = Proc.new { "cannot be blank" }
    person.errors.add(:name, message)
    assert person.errors.added?(:name, message)
  end

  test "added? defaults message to :invalid" do
    person = Person.new
    person.errors.add(:name)
    assert person.errors.added?(:name)
  end

  test "added? matches the given message when several errors are present for the same attribute" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    person.errors.add(:name, "is invalid")
    assert person.errors.added?(:name, "cannot be blank")
  end

  test "added? returns false when no errors are present" do
    person = Person.new
    assert !person.errors.added?(:name)
  end

  test "added? returns false when checking a nonexisting error and other errors are present for the given attribute" do
    person = Person.new
    person.errors.add(:name, "is invalid")
    assert !person.errors.added?(:name, "cannot be blank")
  end

  test "size calculates the number of error messages" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    assert_equal 1, person.errors.size
  end

  test "count calculates the number of error messages" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    assert_equal 1, person.errors.count
  end

  test "to_a returns the list of errors with complete messages containing the attribute names" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    person.errors.add(:name, "cannot be nil")
    assert_equal ["name cannot be blank", "name cannot be nil"], person.errors.to_a
  end

  test "to_hash returns the error messages hash" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    assert_equal({ name: ["cannot be blank"] }, person.errors.to_hash)
  end

  test "full_messages creates a list of error messages with the attribute name included" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    person.errors.add(:name, "cannot be nil")
    assert_equal ["name cannot be blank", "name cannot be nil"], person.errors.full_messages
  end

  test "full_messages_for contains all the error messages for the given attribute" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    person.errors.add(:name, "cannot be nil")
    assert_equal ["name cannot be blank", "name cannot be nil"], person.errors.full_messages_for(:name)
  end

  test "full_messages_for does not contain error messages from other attributes" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    person.errors.add(:email, "cannot be blank")
    assert_equal ["name cannot be blank"], person.errors.full_messages_for(:name)
  end

  test "full_messages_for returns an empty list in case there are no errors for the given attribute" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    assert_equal [], person.errors.full_messages_for(:email)
  end

  test "full_message returns the given message when attribute is :base" do
    person = Person.new
    assert_equal "press the button", person.errors.full_message(:base, "press the button")
  end

  test "full_message returns the given message with the attribute name included" do
    person = Person.new
    assert_equal "name cannot be blank", person.errors.full_message(:name, "cannot be blank")
    assert_equal "name_test cannot be blank", person.errors.full_message(:name_test, "cannot be blank")
  end

  test "as_json creates a json formatted representation of the errors hash" do
    person = Person.new
    person.validate!

    assert_equal({ name: ["cannot be nil"] }, person.errors.as_json)
  end

  test "as_json with :full_messages option creates a json formatted representation of the errors containing complete messages" do
    person = Person.new
    person.validate!

    assert_equal({ name: ["name cannot be nil"] }, person.errors.as_json(full_messages: true))
  end

  test "generate_message works without i18n_scope" do
    person = Person.new
    assert !Person.respond_to?(:i18n_scope)
    assert_nothing_raised {
      person.errors.generate_message(:name, :blank)
    }
  end

  test "add_on_empty generates message" do
    person = Person.new
    assert_called_with(person.errors, :generate_message, [:name, :empty, {}]) do
      assert_deprecated do
        person.errors.add_on_empty :name
      end
    end
  end

  test "add_on_empty generates message for multiple attributes" do
    person = Person.new
    expected_calls = [ [:name, :empty, {}], [:age, :empty, {}] ]
    assert_called_with(person.errors, :generate_message, expected_calls) do
      assert_deprecated do
        person.errors.add_on_empty [:name, :age]
      end
    end
  end

  test "add_on_empty generates message with custom default message" do
    person = Person.new
    assert_called_with(person.errors, :generate_message, [:name, :empty, { message: 'custom' }]) do
      assert_deprecated do
        person.errors.add_on_empty :name, message: 'custom'
      end
    end
  end

  test "add_on_empty generates message with empty string value" do
    person = Person.new
    person.name = ''
    assert_called_with(person.errors, :generate_message, [:name, :empty, {}]) do
      assert_deprecated do
        person.errors.add_on_empty :name
      end
    end
  end

  test "add_on_blank generates message" do
    person = Person.new
    assert_called_with(person.errors, :generate_message, [:name, :blank, {}]) do
      assert_deprecated do
        person.errors.add_on_blank :name
      end
    end
  end

  test "add_on_blank generates message for multiple attributes" do
    person = Person.new
    expected_calls = [ [:name, :blank, {}], [:age, :blank, {}] ]
    assert_called_with(person.errors, :generate_message, expected_calls) do
      assert_deprecated do
        person.errors.add_on_blank [:name, :age]
      end
    end
  end

  test "add_on_blank generates message with custom default message" do
    person = Person.new
    assert_called_with(person.errors, :generate_message, [:name, :blank, { message: 'custom' }]) do
      assert_deprecated do
        person.errors.add_on_blank :name, message: 'custom'
      end
    end
  end

  test "details returns added error detail" do
    person = Person.new
    person.errors.add(:name, :invalid)
    assert_equal({ name: [{ error: :invalid }] }, person.errors.details)
  end

  test "details returns added error detail with custom option" do
    person = Person.new
    person.errors.add(:name, :greater_than, count: 5)
    assert_equal({ name: [{ error: :greater_than, count: 5 }] }, person.errors.details)
  end

  test "details do not include message option" do
    person = Person.new
    person.errors.add(:name, :invalid, message: "is bad")
    assert_equal({ name: [{ error: :invalid }] }, person.errors.details)
  end

  test "dup duplicates details" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :invalid)
    errors_dup = errors.dup
    errors_dup.add(:name, :taken)
    assert_not_equal errors_dup.details, errors.details
  end

  test "delete removes details on given attribute" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :invalid)
    errors.delete(:name)
    assert_empty errors.details[:name]
  end

  test "delete returns the deleted messages" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :invalid)
    assert_equal ["is invalid"], errors.delete(:name)
  end

  test "clear removes details" do
    person = Person.new
    person.errors.add(:name, :invalid)

    assert_equal 1, person.errors.details.count
    person.errors.clear
    assert person.errors.details.empty?
  end

  test "copy errors" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :invalid)
    person = Person.new
    person.errors.copy!(errors)

    assert_equal [:name], person.errors.messages.keys
    assert_equal [:name], person.errors.details.keys
  end
end
