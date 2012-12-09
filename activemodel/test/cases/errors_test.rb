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

  def test_delete
    errors = ActiveModel::Errors.new(self)
    errors[:foo] = 'omg'
    errors.delete(:foo)
    assert_empty errors[:foo]
  end

  def test_include?
    errors = ActiveModel::Errors.new(self)
    errors[:foo] = 'omg'
    assert errors.include?(:foo), 'errors should include :foo'
  end

  def test_dup
    errors = ActiveModel::Errors.new(self)
    errors[:foo] = 'bar'
    errors_dup = errors.dup
    errors_dup[:bar] = 'omg'
    assert_not_same errors_dup.messages, errors.messages
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

  test "should be able to add an error with a symbol" do
    person = Person.new
    person.errors.add(:name, :blank)
    message = person.errors.generate_message(:name, :blank)
    assert_equal [message], person.errors[:name]
  end

  test "should be able to add an error with a proc" do
    person = Person.new
    message = Proc.new { "can not be blank" }
    person.errors.add(:name, message)
    assert_equal ["can not be blank"], person.errors[:name]
  end

  test "added? should be true if that error was added" do
    person = Person.new
    person.errors.add(:name, "can not be blank")
    assert person.errors.added?(:name, "can not be blank")
  end

  test "added? should handle when message is a symbol" do
    person = Person.new
    person.errors.add(:name, :blank)
    assert person.errors.added?(:name, :blank)
  end

  test "added? should handle when message is a proc" do
    person = Person.new
    message = Proc.new { "can not be blank" }
    person.errors.add(:name, message)
    assert person.errors.added?(:name, message)
  end

  test "added? should default message to :invalid" do
    person = Person.new
    person.errors.add(:name)
    assert person.errors.added?(:name)
  end

  test "added? should be true when several errors are present, and we ask for one of them" do
    person = Person.new
    person.errors.add(:name, "can not be blank")
    person.errors.add(:name, "is invalid")
    assert person.errors.added?(:name, "can not be blank")
  end

  test "added? should be false if no errors are present" do
    person = Person.new
    assert !person.errors.added?(:name)
  end

  test "added? should be false when an error is present, but we check for another error" do
    person = Person.new
    person.errors.add(:name, "is invalid")
    assert !person.errors.added?(:name, "can not be blank")
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

  test 'to_hash should return a hash' do
    person = Person.new
    person.errors.add(:name, "can not be blank")
    assert_instance_of ::Hash, person.errors.to_hash
  end

  test 'full_messages should return an array of error messages, with the attribute name included' do
    person = Person.new
    person.errors.add(:name, "can not be blank")
    person.errors.add(:name, "can not be nil")
    assert_equal ["name can not be blank", "name can not be nil"], person.errors.full_messages
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

  test 'should return a JSON hash representation of the errors with full messages' do
    person = Person.new
    person.errors.add(:name, "can not be blank")
    person.errors.add(:name, "can not be nil")
    person.errors.add(:email, "is invalid")
    hash = person.errors.as_json(:full_messages => true)
    assert_equal ["name can not be blank", "name can not be nil"], hash[:name]
    assert_equal ["email is invalid"], hash[:email]
  end

  test "generate_message should work without i18n_scope" do
    person = Person.new
    assert !Person.respond_to?(:i18n_scope)
    assert_nothing_raised {
      person.errors.generate_message(:name, :blank)
    }
  end

  test "add_on_empty generates message" do
    person = Person.new
    person.errors.expects(:generate_message).with(:name, :empty, {})
    person.errors.add_on_empty :name
  end

  test "add_on_empty generates message for multiple attributes" do
    person = Person.new
    person.errors.expects(:generate_message).with(:name, :empty, {})
    person.errors.expects(:generate_message).with(:age, :empty, {})
    person.errors.add_on_empty [:name, :age]
  end

  test "add_on_empty generates message with custom default message" do
    person = Person.new
    person.errors.expects(:generate_message).with(:name, :empty, {:message => 'custom'})
    person.errors.add_on_empty :name, :message => 'custom'
  end

  test "add_on_blank generates message" do
    person = Person.new
    person.errors.expects(:generate_message).with(:name, :blank, {})
    person.errors.add_on_blank :name
  end

  test "add_on_blank generates message for multiple attributes" do
    person = Person.new
    person.errors.expects(:generate_message).with(:name, :blank, {})
    person.errors.expects(:generate_message).with(:age, :blank, {})
    person.errors.add_on_blank [:name, :age]
  end

  test "add_on_blank generates message with custom default message" do
    person = Person.new
    person.errors.expects(:generate_message).with(:name, :blank, {:message => 'custom'})
    person.errors.add_on_blank :name, :message => 'custom'
  end
end
