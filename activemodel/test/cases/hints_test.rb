require "cases/helper"

class HintsTest < ActiveModel::TestCase
  class Person
    extend ActiveModel::Naming
    include ActiveModel::Validations
    def initialize
      @hints = ActiveModel::Hints.new(self)
    end

    attr_accessor :name, :age
    attr_reader   :hints

    validates :name, :presence => true

    def self.human_attribute_name(attr, options = {})
      attr
    end

    def attributes
      { name: 'Juan', age: 7 }
    end

    def self.lookup_ancestors
      [self]
    end
  end

  class PersonWithoutValidators
    extend ActiveModel::Naming
    include ActiveModel::Validations
    def initialize
      @hints = ActiveModel::Hints.new(self)
    end

    attr_accessor :name, :age
    attr_reader   :hints

    def self.human_attribute_name(attr, options = {})
      attr
    end

    def attributes
      { name: 'Juan', age: 7 }
    end

    def self.lookup_ancestors
      [self]
    end
  end

  def test_delete
    hints = Person.new.hints
    hints[:foo] = 'omg'
    hints.delete(:foo)
    assert_empty hints[:foo]
  end

  def test_include?
    hints = Person.new.hints
    hints[:foo] = 'omg'
    assert hints.include?(:foo), 'hints should include :foo'
  end

  def test_dup
    hints = Person.new.hints
    hints[:foo] = 'bar'
    hints_dup = hints.dup
    hints_dup[:bar] = 'omg'
    assert_not_same hints_dup.messages, hints.messages
  end

  def test_has_key?
    hints = Person.new.hints
    hints[:foo] = 'omg'
    assert hints.has_key?(:foo), 'hints should have key :foo'
  end

  test "should return and empty hash if there are no validators" do
    person = PersonWithoutValidators.new
    person.hints[:foo]
    assert person.hints.empty?
    assert person.hints.blank?
    assert !person.hints.include?(:foo)
  end

  test "should return a non empty hash if there are validators" do
    person = Person.new
    person.hints[:foo]
    assert person.hints.messages.length > 0
    assert !person.hints.blank?
  end

  test 'should be able to assign hint' do
    person = PersonWithoutValidators.new
    person.hints[:name] = 'should not be nil'
    assert_equal ["should not be nil"], person.hints[:name]
  end

  test 'should be able to add an hint on an attribute' do
    person = PersonWithoutValidators.new
    person.hints.add(:name, "can not be blank")
    assert_equal ["can not be blank"], person.hints[:name]
  end

  test "should be able to add an hint with a symbol" do
    person = PersonWithoutValidators.new
    person.hints.add(:name, :blank)
    message = person.hints.generate_message(:name, :blank)
    assert_equal [message], person.hints[:name]
  end

  test "should be able to add an hint with a proc" do
    person = PersonWithoutValidators.new
    message = Proc.new { "can not be blank" }
    person.hints.add(:name, message)
    assert_equal ["can not be blank"], person.hints[:name]
  end

  test "added? should be true if that hint was added" do
    person = Person.new
    person.hints.add(:name, "can not be blank")
    assert person.hints.added?(:name, "can not be blank")
  end

  test "added? should handle when message is a symbol" do
    person = Person.new
    person.hints.add(:name, :blank)
    assert person.hints.added?(:name, :blank)
  end

  test "added? should handle when message is a proc" do
    person = Person.new
    message = Proc.new { "can not be blank" }
    person.hints.add(:name, message)
    assert person.hints.added?(:name, message)
  end

  test "added? should default message to :invalid" do
    person = Person.new
    person.hints.add(:name)
    assert person.hints.added?(:name)
  end

  test "added? should be true when several hints are present, and we ask for one of them" do
    person = Person.new
    person.hints.add(:name, "can not be blank")
    person.hints.add(:name, "is invalid")
    assert person.hints.added?(:name, "can not be blank")
  end

  test "added? should be false if no hints are present" do
    person = Person.new
    assert !person.hints.added?(:name)
  end

  test "added? should be false when an hint is present, but we check for another hint" do
    person = Person.new
    person.hints.add(:name, "is invalid")
    assert !person.hints.added?(:name, "can not be blank")
  end

  test 'should respond to size' do
    person = Person.new
    q = person.hints.size
    person.hints.add(:name, "can not be blank")
    assert_equal 1 + q, person.hints.size
  end

  test 'to_a should return an array' do
    person = PersonWithoutValidators.new
    person.hints.add(:name, "can not be blank")
    person.hints.add(:name, "can not be nil")
    assert_equal ["name can not be blank", "name can not be nil"], person.hints.to_a
  end

  test 'to_hash should return a ActiveSupport::OrderedHash' do # is this still needed or can it be a hash?
    person = Person.new
    person.hints.add(:name, "can not be blank")
    assert_instance_of ActiveSupport::OrderedHash, person.hints.to_hash
  end

  test 'full_messages should return an array of hint messages, with the attribute name included' do
    person = PersonWithoutValidators.new
    person.hints.add(:name, "can not be blank")
    person.hints.add(:name, "can not be nil")
    assert_equal ["name can not be blank", "name can not be nil"], person.hints.full_messages
  end

  test 'full_message should return the given message if attribute equals :base' do
    person = PersonWithoutValidators.new
    assert_equal "press the button", person.hints.full_message(:base, "press the button")
  end

  test 'full_message should return the given message with the attribute name included' do
    person = PersonWithoutValidators.new
    assert_equal "name can not be blank", person.hints.full_message(:name, "can not be blank")
  end

  test 'should return a JSON hash representation of the hints' do
    person = PersonWithoutValidators.new
    person.hints.add(:name, "can not be blank")
    person.hints.add(:name, "can not be nil")
    person.hints.add(:email, "is invalid")
    hash = person.hints.as_json
    assert_equal ["can not be blank", "can not be nil"], hash[:name]
    assert_equal ["is invalid"], hash[:email]
  end

  test 'should return a JSON hash representation of the hints with full messages' do
    person = PersonWithoutValidators.new
    person.hints.add(:name, "can not be blank")
    person.hints.add(:name, "can not be nil")
    person.hints.add(:email, "is invalid")
    hash = person.hints.as_json(:full_messages => true)
    assert_equal ["name can not be blank", "name can not be nil"], hash[:name]
    assert_equal ["email is invalid"], hash[:email]
  end

  test "generate_message should work without i18n_scope" do
    person = PersonWithoutValidators.new
#    assert !PersonWithoutValidators.respond_to?(:i18n_scope)
    assert_nothing_raised {
      person.hints.generate_message(:name, :blank)
    }
  end

  test "add_on_empty generates message" do
    person = Person.new
    person.hints.expects(:generate_message).with(:name, :empty, {})
    person.hints.add_on_empty :name
  end

  test "add_on_empty generates message for multiple attributes" do
    person = Person.new
    person.hints.expects(:generate_message).with(:name, :empty, {})
    person.hints.expects(:generate_message).with(:age, :empty, {})
    person.hints.add_on_empty [:name, :age]
  end

  test "add_on_empty generates message with custom default message" do
    person = Person.new
    person.hints.expects(:generate_message).with(:name, :empty, {:message => 'custom'})
    person.hints.add_on_empty :name, :message => 'custom'
  end

  test "add_on_blank generates message" do
    person = Person.new
    person.hints.expects(:generate_message).with(:name, :blank, {})
    person.hints.add_on_blank :name
  end

  test "add_on_blank generates message for multiple attributes" do
    person = Person.new
    person.hints.expects(:generate_message).with(:name, :blank, {})
    person.hints.expects(:generate_message).with(:age, :blank, {})
    person.hints.add_on_blank [:name, :age]
  end

  test "add_on_blank generates message with custom default message" do
    person = Person.new
    person.hints.expects(:generate_message).with(:name, :blank, {:message => 'custom'})
    person.hints.add_on_blank :name, :message => 'custom'
  end
end
