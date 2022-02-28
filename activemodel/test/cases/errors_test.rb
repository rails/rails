# frozen_string_literal: true

require "cases/helper"
require "yaml"

class ErrorsTest < ActiveModel::TestCase
  class Person
    extend ActiveModel::Naming
    def initialize
      @errors = ActiveModel::Errors.new(self)
    end

    attr_accessor :name, :age, :gender, :city
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
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :blank)
    errors.delete("name")
    assert_empty errors[:name]
  end

  def test_include?
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:foo, "omg")
    assert_includes errors, :foo, "errors should include :foo"
    assert_includes errors, "foo", "errors should include 'foo' as :foo"
  end

  def test_each_when_arity_is_negative
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :blank)
    errors.add(:gender, :blank)

    assert_equal([:name, :gender], errors.map(&:attribute))
  end

  def test_any?
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name)
    assert errors.any?, "any? should return true"
    assert errors.any? { |_| true }, "any? should return true"
  end

  def test_first
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :blank)

    error = errors.first
    assert_kind_of ActiveModel::Error, error
  end

  def test_dup
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name)
    errors_dup = errors.dup
    assert_not_same errors_dup.errors, errors.errors
  end

  def test_has_key?
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:foo, "omg")
    assert_equal true, errors.has_key?(:foo), "errors should have key :foo"
    assert_equal true, errors.has_key?("foo"), "errors should have key 'foo' as :foo"
  end

  def test_has_no_key
    errors = ActiveModel::Errors.new(Person.new)
    assert_equal false, errors.has_key?(:name), "errors should not have key :name"
  end

  def test_key?
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:foo, "omg")
    assert_equal true, errors.key?(:foo), "errors should have key :foo"
    assert_equal true, errors.key?("foo"), "errors should have key 'foo' as :foo"
  end

  def test_no_key
    errors = ActiveModel::Errors.new(Person.new)
    assert_equal false, errors.key?(:name), "errors should not have key :name"
  end

  test "clear errors" do
    person = Person.new
    person.validate!

    assert_equal 1, person.errors.count
    person.errors.clear
    assert_empty person.errors
  end

  test "error access is indifferent" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, "omg")

    assert_equal ["omg"], errors["name"]
  end

  test "attribute_names returns the error attributes" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:foo, "omg")
    errors.add(:baz, "zomg")

    assert_equal [:foo, :baz], errors.attribute_names
  end

  test "attribute_names only returns unique attribute names" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:foo, "omg")
    errors.add(:foo, "zomg")

    assert_equal [:foo], errors.attribute_names
  end

  test "attribute_names returns an empty array after try to get a message only" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.messages[:foo]
    errors.messages[:baz]

    assert_equal [], errors.attribute_names
  end

  test "detecting whether there are errors with empty?, blank?, include?" do
    person = Person.new
    person.errors[:foo]
    assert_empty person.errors
    assert_predicate person.errors, :blank?
    assert_not_includes person.errors, :foo

    person.errors.add(:foo, "New error")
    assert_not_empty person.errors
    assert_not_predicate person.errors, :blank?
    assert_includes person.errors, :foo
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

  test "add creates an error object and returns it" do
    person = Person.new
    error = person.errors.add(:name, :blank)

    assert_equal :name, error.attribute
    assert_equal :blank, error.type
    assert_equal error, person.errors.objects.first
  end

  test "add, with type as symbol" do
    person = Person.new
    person.errors.add(:name, :blank)

    assert_equal :blank, person.errors.objects.first.type
    assert_equal ["can't be blank"], person.errors[:name]
  end

  test "add, with type as String" do
    msg = "custom msg"

    person = Person.new
    person.errors.add(:name, msg)

    assert_equal [msg], person.errors[:name]
  end

  test "add, with type as nil" do
    person = Person.new
    person.errors.add(:name)

    assert_equal :invalid, person.errors.objects.first.type
    assert_equal ["is invalid"], person.errors[:name]
  end

  test "add, with type as Proc, which evaluates to String" do
    msg = "custom msg"
    type = Proc.new { msg }

    person = Person.new
    person.errors.add(:name, type)

    assert_equal [msg], person.errors[:name]
  end

  test "add, type being Proc, which evaluates to Symbol" do
    type = Proc.new { :blank }

    person = Person.new
    person.errors.add(:name, type)

    assert_equal :blank, person.errors.objects.first.type
    assert_equal ["can't be blank"], person.errors[:name]
  end

  test "add an error message on a specific attribute with a defined type" do
    person = Person.new
    person.errors.add(:name, :blank, message: "cannot be blank")
    assert_equal ["cannot be blank"], person.errors[:name]
  end

  test "initialize options[:message] as Proc, which evaluates to String" do
    msg = "custom msg"
    type = Proc.new { msg }

    person = Person.new
    person.errors.add(:name, :blank, message: type)

    assert_equal :blank, person.errors.objects.first.type
    assert_equal [msg], person.errors[:name]
  end

  test "add, with options[:message] as Proc, which evaluates to String, where type is nil" do
    msg = "custom msg"
    type = Proc.new { msg }

    person = Person.new
    person.errors.add(:name, message: type)

    assert_equal :invalid, person.errors.objects.first.type
    assert_equal [msg], person.errors[:name]
  end

  test "added? when attribute was added through a collection" do
    person = Person.new
    person.errors.add(:"family_members.name", :too_long, count: 25)
    assert person.errors.added?(:"family_members.name", :too_long, count: 25)
    assert_not person.errors.added?(:"family_members.name", :too_long)
    assert_not person.errors.added?(:"family_members.name", :too_long, name: "hello")
  end

  test "added? ignores callback option" do
    person = Person.new

    person.errors.add(:name, :too_long, if: -> { true })
    assert person.errors.added?(:name, :too_long)
  end

  test "added? ignores message option" do
    person = Person.new

    person.errors.add(:name, :too_long, message: proc { "foo" })
    assert person.errors.added?(:name, :too_long)
  end

  test "added? detects indifferent if a specific error was added to the object" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    assert person.errors.added?(:name, "cannot be blank")
    assert person.errors.added?("name", "cannot be blank")
  end

  test "added? handles symbol message" do
    person = Person.new
    person.errors.add(:name, :blank)
    assert person.errors.added?(:name, :blank)
  end

  test "added? returns true when string attribute is used with a symbol message" do
    person = Person.new
    person.errors.add(:name, :blank)
    assert person.errors.added?("name", :blank)
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
    assert person.errors.added?(:name, "is invalid")
    assert_not person.errors.added?(:name, "incorrect")
  end

  test "added? returns false when no errors are present" do
    person = Person.new
    assert_not person.errors.added?(:name)
  end

  test "added? returns false when checking a nonexisting error and other errors are present for the given attribute" do
    person = Person.new
    person.errors.add(:name, "is invalid")
    assert_not person.errors.added?(:name, "cannot be blank")
  end

  test "added? returns false when checking for an error, but not providing message argument" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    assert_not person.errors.added?(:name)
  end

  test "added? returns false when checking for an error with an incorrect or missing option" do
    person = Person.new
    person.errors.add :name, :too_long, count: 25

    assert person.errors.added? :name, :too_long, count: 25
    assert person.errors.added? :name, "is too long (maximum is 25 characters)"
    assert_not person.errors.added? :name, :too_long, count: 24
    assert_not person.errors.added? :name, :too_long
    assert_not person.errors.added? :name, "is too long"
  end

  test "added? returns false when checking for an error by symbol and a different error with same message is present" do
    I18n.backend.store_translations("en", errors: { attributes: { name: { wrong: "is wrong", used: "is wrong" } } })
    person = Person.new
    person.errors.add(:name, :wrong)
    assert_not person.errors.added?(:name, :used)
    assert person.errors.added?(:name, :wrong)
  end

  test "of_kind? returns false when checking for an error, but not providing message argument" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    assert_not person.errors.of_kind?(:name)
  end

  test "of_kind? returns false when checking a nonexisting error and other errors are present for the given attribute" do
    person = Person.new
    person.errors.add(:name, "is invalid")
    assert_not person.errors.of_kind?(:name, "cannot be blank")
  end

  test "of_kind? returns false when no errors are present" do
    person = Person.new
    assert_not person.errors.of_kind?(:name)
  end

  test "of_kind? matches the given message when several errors are present for the same attribute" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    person.errors.add(:name, "is invalid")
    assert person.errors.of_kind?(:name, "cannot be blank")
    assert person.errors.of_kind?(:name, "is invalid")
    assert_not person.errors.of_kind?(:name, "incorrect")
  end

  test "of_kind? defaults message to :invalid" do
    person = Person.new
    person.errors.add(:name)
    assert person.errors.of_kind?(:name)
  end

  test "of_kind? handles proc messages" do
    person = Person.new
    message = Proc.new { "cannot be blank" }
    person.errors.add(:name, message)
    assert person.errors.of_kind?(:name, message)
  end

  test "of_kind? returns true when string attribute is used with a symbol message" do
    person = Person.new
    person.errors.add(:name, :blank)
    assert person.errors.of_kind?("name", :blank)
  end

  test "of_kind? handles symbol message" do
    person = Person.new
    person.errors.add(:name, :blank)
    assert person.errors.of_kind?(:name, :blank)
  end

  test "of_kind? detects indifferent if a specific error was added to the object" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    assert person.errors.of_kind?(:name, "cannot be blank")
    assert person.errors.of_kind?("name", "cannot be blank")
  end

  test "of_kind? ignores options" do
    person = Person.new
    person.errors.add :name, :too_long, count: 25

    assert person.errors.of_kind? :name, :too_long
    assert person.errors.of_kind? :name, "is too long (maximum is 25 characters)"
  end

  test "of_kind? returns false when checking for an error by symbol and a different error with same message is present" do
    I18n.backend.store_translations("en", errors: { attributes: { name: { wrong: "is wrong", used: "is wrong" } } })
    person = Person.new
    person.errors.add(:name, :wrong)
    assert_not person.errors.of_kind?(:name, :used)
    assert person.errors.of_kind?(:name, :wrong)
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

  test "to_hash returns a hash without default proc" do
    person = Person.new
    assert_nil person.errors.to_hash.default_proc
  end

  test "as_json returns a hash without default proc" do
    person = Person.new
    assert_nil person.errors.as_json.default_proc
  end

  test "messages returns empty frozen array when when accessed with non-existent attribute" do
    errors = ActiveModel::Errors.new(Person.new)

    assert_equal [], errors.messages[:foo]
    assert_raises(FrozenError) { errors.messages[:foo] << "foo" }
    assert_raises(FrozenError) { errors.messages[:foo].clear }
  end

  test "full_messages doesn't require the base object to respond to `:errors" do
    model = Class.new do
      def initialize
        @errors = ActiveModel::Errors.new(self)
        @errors.add(:name, "bar")
      end

      def self.human_attribute_name(attr, options = {})
        "foo"
      end

      def call
        error_wrapper = Struct.new(:model_errors)

        error_wrapper.new(@errors)
      end
    end

    assert_equal(["foo bar"], model.new.call.model_errors.full_messages)
  end

  test "full_messages creates a list of error messages with the attribute name included" do
    person = Person.new
    person.errors.add(:name, "cannot be blank")
    person.errors.add(:name, "cannot be nil")
    assert_equal ["name cannot be blank", "name cannot be nil"], person.errors.full_messages
  end

  test "full_messages_for contains all the error messages for the given attribute indifferent" do
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
    assert_equal ["name cannot be blank"], person.errors.full_messages_for("name")
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
    assert_not_respond_to Person, :i18n_scope
    assert_nothing_raised {
      person.errors.generate_message(:name, :blank)
    }
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

  test "details retains original type as error" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, "cannot be nil")
    errors.add("foo", "bar")
    errors.add(:baz, nil)
    errors.add(:age, :invalid, count: 3, message: "%{count} is too low")

    assert_equal(
      {
        name: [{ error: "cannot be nil" }],
        foo: [{ error: "bar" }],
        baz: [{ error: nil }],
        age: [{ error: :invalid, count: 3 }]
      },
      errors.details
    )
  end

  test "group_by_attribute" do
    person = Person.new
    error = person.errors.add(:name, :invalid, message: "is bad")
    hash = person.errors.group_by_attribute

    assert_equal({ name: [error] }, hash)
  end

  test "dup duplicates details" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :invalid)
    errors_dup = errors.dup
    errors_dup.add(:name, :taken)
    assert_not_equal errors_dup.details, errors.details
  end

  test "delete returns nil when no errors were deleted" do
    errors = ActiveModel::Errors.new(Person.new)

    assert_nil(errors.delete(:name))
  end

  test "delete removes details on given attribute" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :invalid)
    errors.delete(:name)
    assert_not errors.added?(:name)
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
    assert_empty person.errors.details
  end

  test "details returns empty array when accessed with non-existent attribute" do
    errors = ActiveModel::Errors.new(Person.new)

    assert_equal [], errors.details[:foo]
    assert_raises(FrozenError) { errors.details[:foo] << "foo" }
    assert_raises(FrozenError) { errors.details[:foo].clear }
  end

  test "copy errors" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :invalid)
    person = Person.new
    person.errors.copy!(errors)

    assert person.errors.added?(:name, :invalid)
    person.errors.each do |error|
      assert_same person, error.base
    end
  end

  test "merge errors" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :invalid)

    person = Person.new
    person.errors.add(:name, :blank)
    person.errors.merge!(errors)

    assert(person.errors.added?(:name, :invalid))
    assert(person.errors.added?(:name, :blank))
  end

  test "merge does not import errors when merging with self" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :invalid)
    errors_before_merge = errors.dup

    errors.merge!(errors)

    assert_equal errors.errors, errors_before_merge.errors
  end

  test "errors are marshalable" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:name, :invalid)
    serialized = Marshal.load(Marshal.dump(errors))

    assert_equal Person, serialized.instance_variable_get(:@base).class
    assert_equal errors.messages, serialized.messages
    assert_equal errors.details, serialized.details
  end

  test "errors are compatible with YAML dumped from Rails 6.x" do
    yaml = <<~CODE
    --- !ruby/object:ActiveModel::Errors
    base: &1 !ruby/object:ErrorsTest::Person
      errors: !ruby/object:ActiveModel::Errors
        base: *1
        errors: []
    errors:
    - !ruby/object:ActiveModel::Error
      base: *1
      attribute: :name
      type: :invalid
      raw_type: :invalid
      options: {}
    CODE

    errors = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(yaml) : YAML.load(yaml)
    assert_equal({ name: ["is invalid"] }, errors.messages)
    assert_equal({ name: [{ error: :invalid }] }, errors.details)

    errors.clear
    assert_equal({}, errors.messages)
    assert_equal({}, errors.details)
  end

  test "inspect" do
    errors = ActiveModel::Errors.new(Person.new)
    errors.add(:base)

    assert_equal(%(#<ActiveModel::Errors [#{errors.first.inspect}]>), errors.inspect)
  end
end
