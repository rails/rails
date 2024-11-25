# frozen_string_literal: true

require "cases/helper"

require "models/topic"
require "models/person"
require "models/reply"
require "models/custom_reader"

require "active_support/json"
require "active_support/xml_mini"

class ValidationsTest < ActiveModel::TestCase
  class CustomStrictValidationException < StandardError; end

  def teardown
    Topic.clear_validators!
    Person.clear_validators!
  end

  def test_single_field_validation
    r = Reply.new
    r.title = "There's no content!"
    assert_predicate r, :invalid?, "A reply without content should be invalid"
    assert r.after_validation_performed, "after_validation callback should be called"

    r.content = "Messa content!"
    assert_predicate r, :valid?, "A reply with content should be valid"
    assert r.after_validation_performed, "after_validation callback should be called"
  end

  def test_single_attr_validation_and_error_msg
    r = Reply.new
    r.title = "There's no content!"
    assert_predicate r, :invalid?
    assert_predicate r.errors[:content], :any?, "A reply without content should mark that attribute as invalid"
    assert_equal ["is Empty"], r.errors["content"], "A reply without content should contain an error"
    assert_equal 1, r.errors.count
  end

  def test_double_attr_validation_and_error_msg
    r = Reply.new
    assert_predicate r, :invalid?

    assert_predicate r.errors[:title], :any?, "A reply without title should mark that attribute as invalid"
    assert_equal ["is Empty"], r.errors["title"], "A reply without title should contain an error"

    assert_predicate r.errors[:content], :any?, "A reply without content should mark that attribute as invalid"
    assert_equal ["is Empty"], r.errors["content"], "A reply without content should contain an error"

    assert_equal 2, r.errors.count
  end

  def test_multiple_errors_per_attr_iteration_with_full_error_composition
    r = Reply.new
    r.title   = ""
    r.content = ""
    r.valid?

    errors = r.errors.to_a

    assert_equal "Content is Empty", errors[0]
    assert_equal "Title is Empty", errors[1]
    assert_equal 2, r.errors.count
  end

  def test_errors_on_nested_attributes_expands_name
    t = Topic.new
    t.errors.add("replies.name", "can't be blank")
    assert_equal ["Replies name can't be blank"], t.errors.full_messages
  end

  def test_errors_on_base
    r = Reply.new
    r.content = "Mismatch"
    r.valid?
    r.errors.add(:base, "Reply is not dignifying")

    errors = r.errors.to_a.inject([]) { |result, error| result + [error] }

    assert_equal ["Reply is not dignifying"], r.errors[:base]

    assert_includes errors, "Title is Empty"
    assert_includes errors, "Reply is not dignifying"
    assert_equal 2, r.errors.count
  end

  def test_errors_on_base_with_symbol_message
    r = Reply.new
    r.content = "Mismatch"
    r.valid?
    r.errors.add(:base, :invalid)

    errors = r.errors.to_a.inject([]) { |result, error| result + [error] }

    assert_equal ["is invalid"], r.errors[:base]

    assert_includes errors, "Title is Empty"
    assert_includes errors, "is invalid"

    assert_equal 2, r.errors.count
  end

  def test_errors_empty_after_errors_on_check
    t = Topic.new
    assert_empty t.errors[:id]
    assert_empty t.errors
  end

  def test_validates_each
    hits = 0
    Topic.validates_each(:title, :content, [:title, :content]) do |record, attr|
      record.errors.add attr, "gotcha"
      hits += 1
    end
    t = Topic.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_equal 4, hits
    assert_equal %w(gotcha gotcha), t.errors[:title]
    assert_equal %w(gotcha gotcha), t.errors[:content]
  end

  def test_validates_each_custom_reader
    hits = 0
    CustomReader.validates_each(:title, :content, [:title, :content]) do |record, attr|
      record.errors.add attr, "gotcha"
      hits += 1
    end
    t = CustomReader.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_equal 4, hits
    assert_equal %w(gotcha gotcha), t.errors[:title]
    assert_equal %w(gotcha gotcha), t.errors[:content]
  ensure
    CustomReader.clear_validators!
  end

  def test_validate_block
    Topic.validate { errors.add("title", "will never be valid") }
    t = Topic.new("title" => "Title", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["will never be valid"], t.errors["title"]
  end

  def test_validate_block_with_params
    Topic.validate { |topic| topic.errors.add("title", "will never be valid") }
    t = Topic.new("title" => "Title", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["will never be valid"], t.errors["title"]
  end

  def test_validates_with_array_condition_does_not_mutate_the_array
    opts = []
    Topic.validate(if: opts, on: :create) { }
    assert_empty opts
  end

  def test_invalid_validator
    Topic.validate :i_dont_exist
    assert_raises(NoMethodError) do
      t = Topic.new
      t.valid?
    end
  end

  def test_invalid_options_to_validate
    error = assert_raises(ArgumentError) do
      # A common mistake -- we meant to call 'validates'
      Topic.validate :title, presence: true
    end
    message = "Unknown key: :presence. Valid keys are: :on, :if, :unless, :prepend, :except_on. Perhaps you meant to call `validates` instead of `validate`?"
    assert_equal message, error.message
  end

  def test_callback_options_to_validate
    klass = Class.new(Topic) do
      attr_reader :call_sequence

      def initialize(*)
        super
        @call_sequence = []
      end

      private
        def validator_a
          @call_sequence << :a
        end

        def validator_b
          @call_sequence << :b
        end

        def validator_c
          @call_sequence << :c
        end
    end

    assert_nothing_raised do
      klass.validate :validator_a, if: -> { true }
      klass.validate :validator_b, prepend: true
      klass.validate :validator_c, unless: -> { true }
    end

    t = klass.new

    assert_predicate t, :valid?
    assert_equal [:b, :a], t.call_sequence
  end

  def test_errors_to_json
    Topic.validates_presence_of %w(title content)
    t = Topic.new
    assert_predicate t, :invalid?

    hash = {}
    hash[:title] = ["can't be blank"]
    hash[:content] = ["can't be blank"]
    assert_equal t.errors.to_json, hash.to_json
  end

  def test_validation_order
    Topic.validates_presence_of :title
    Topic.validates_length_of :title, minimum: 2

    t = Topic.new("title" => "")
    assert_predicate t, :invalid?
    assert_equal "can't be blank", t.errors["title"].first
    Topic.validates_presence_of :title, :author_name
    Topic.validate { errors.add("author_email_address", "will never be valid") }
    Topic.validates_length_of :title, :content, minimum: 2

    t = Topic.new title: ""
    assert_predicate t, :invalid?

    assert_equal :title, key = t.errors.attribute_names[0]
    assert_equal "can't be blank", t.errors[key][0]
    assert_equal "is too short (minimum is 2 characters)", t.errors[key][1]
    assert_equal :author_name, key = t.errors.attribute_names[1]
    assert_equal "can't be blank", t.errors[key][0]
    assert_equal :author_email_address, key = t.errors.attribute_names[2]
    assert_equal "will never be valid", t.errors[key][0]
    assert_equal :content, key = t.errors.attribute_names[3]
    assert_equal "is too short (minimum is 2 characters)", t.errors[key][0]
  end

  def test_validation_with_if_and_on
    Topic.validates_presence_of :title, if: Proc.new { |x| x.author_name = "bad"; true }, on: :update

    t = Topic.new(title: "")

    # If block should not fire
    assert_predicate t, :valid?
    assert_predicate t.author_name, :nil?

    # If block should fire
    assert t.invalid?(:update)
    assert t.author_name == "bad"
  end

  def test_invalid_should_be_the_opposite_of_valid
    Topic.validates_presence_of :title

    t = Topic.new
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?

    t.title = "Things are going to change"
    assert_not_predicate t, :invalid?
  end

  def test_validation_with_message_as_proc
    Topic.validates_presence_of(:title, message: proc { "no blanks here".upcase })

    t = Topic.new
    assert_predicate t, :invalid?
    assert_equal ["NO BLANKS HERE"], t.errors[:title]
  end

  def test_list_of_validators_for_model
    Topic.validates_presence_of :title
    Topic.validates_length_of :title, minimum: 2

    assert_equal 2, Topic.validators.count
    assert_equal [:presence, :length], Topic.validators.map(&:kind)
  end

  def test_list_of_validators_on_an_attribute
    Topic.validates_presence_of :title, :content
    Topic.validates_length_of :title, minimum: 2

    assert_equal 2, Topic.validators_on(:title).count
    assert_equal [:presence, :length], Topic.validators_on(:title).map(&:kind)
    assert_equal 1, Topic.validators_on(:content).count
    assert_equal [:presence], Topic.validators_on(:content).map(&:kind)
  end

  def test_accessing_instance_of_validator_on_an_attribute
    Topic.validates_length_of :title, minimum: 10
    assert_equal 10, Topic.validators_on(:title).first.options[:minimum]
  end

  def test_list_of_validators_on_multiple_attributes
    Topic.validates :title, length: { minimum: 10 }
    Topic.validates :author_name, presence: true, format: /a/

    validators = Topic.validators_on(:title, :author_name)

    assert_equal [
      ActiveModel::Validations::FormatValidator,
      ActiveModel::Validations::LengthValidator,
      ActiveModel::Validations::PresenceValidator
    ], validators.map(&:class).sort_by(&:to_s)
  end

  def test_list_of_validators_will_be_empty_when_empty
    Topic.validates :title, length: { minimum: 10 }
    assert_equal [], Topic.validators_on(:author_name)
  end

  def test_validations_on_the_instance_level
    Topic.validates :title, :author_name, presence: true
    Topic.validates :content, length: { minimum: 10 }

    topic = Topic.new
    assert_predicate topic, :invalid?
    assert_equal 3, topic.errors.size

    topic.title = "Some Title"
    topic.author_name = "Some Author"
    topic.content = "Some Content Whose Length is more than 10."
    assert_predicate topic, :valid?
  end

  def test_validate
    Topic.validate do
      validates_presence_of :title, :author_name
      validates_length_of :content, minimum: 10
    end

    topic = Topic.new
    assert_empty topic.errors

    topic.validate
    assert_not_empty topic.errors
  end

  def test_validate_with_bang
    Topic.validates :title, presence: true

    assert_raise(ActiveModel::ValidationError) do
      Topic.new.validate!
    end
  end

  def test_validate_with_bang_and_context
    Topic.validates :title, presence: true, on: :context

    assert_raise(ActiveModel::ValidationError) do
      Topic.new.validate!(:context)
    end

    t = Topic.new(title: "Valid title")
    assert t.validate!(:context)
  end

  def test_strict_validation_in_validates
    Topic.validates :title, strict: true, presence: true
    assert_raises ActiveModel::StrictValidationFailed do
      Topic.new.valid?
    end
  end

  def test_strict_validation_not_fails
    Topic.validates :title, strict: true, presence: true
    assert_predicate Topic.new(title: "hello"), :valid?
  end

  def test_strict_validation_particular_validator
    Topic.validates :title, presence: { strict: true }
    assert_raises ActiveModel::StrictValidationFailed do
      Topic.new.valid?
    end
  end

  def test_strict_validation_in_custom_validator_helper
    Topic.validates_presence_of :title, strict: true
    assert_raises ActiveModel::StrictValidationFailed do
      Topic.new.valid?
    end
  end

  def test_strict_validation_custom_exception
    Topic.validates_presence_of :title, strict: CustomStrictValidationException
    assert_raises CustomStrictValidationException do
      Topic.new.valid?
    end
  end

  def test_validates_with_bang
    Topic.validates! :title, presence: true
    assert_raises ActiveModel::StrictValidationFailed do
      Topic.new.valid?
    end
  end

  def test_validates_with_false_hash_value
    Topic.validates :title, presence: false
    assert_predicate Topic.new, :valid?
  end

  def test_strict_validation_error_message
    Topic.validates :title, strict: true, presence: true

    exception = assert_raises(ActiveModel::StrictValidationFailed) do
      Topic.new.valid?
    end
    assert_equal "Title can't be blank", exception.message
  end

  def test_does_not_modify_options_argument
    options = { presence: true }
    Topic.validates :title, options
    assert_equal({ presence: true }, options)
  end

  def test_dup_validity_is_independent
    Topic.validates_presence_of :title
    topic = Topic.new("title" => "Literature")
    topic.valid?

    duped = topic.dup
    duped.title = nil
    assert_predicate duped, :invalid?

    topic.title = nil
    duped.title = "Mathematics"
    assert_predicate topic, :invalid?
    assert_predicate duped, :valid?
  end

  def test_validation_with_message_as_proc_that_takes_a_record_as_a_parameter
    Topic.validates_presence_of(:title, message: proc { |record| "You have failed me for the last time, #{record.author_name}." })

    t = Topic.new(author_name: "Admiral")
    assert_predicate t, :invalid?
    assert_equal ["You have failed me for the last time, Admiral."], t.errors[:title]
  end

  def test_validation_with_message_as_proc_that_takes_record_and_data_as_a_parameters
    Topic.validates_presence_of(:title, message: proc { |record, data| "#{data[:attribute]} is missing. You have failed me for the last time, #{record.author_name}." })

    t = Topic.new(author_name: "Admiral")
    assert_predicate t, :invalid?
    assert_equal ["Title is missing. You have failed me for the last time, Admiral."], t.errors[:title]
  end

  def test_frozen_models_can_be_validated
    Person.validates :title, presence: true
    person = Person.new.freeze
    assert_predicate person, :frozen?
    assert_not person.valid?
  end

  def test_validate_with_except_on
    Topic.validates :title, presence: true, except_on: :custom_context

    topic = Topic.new
    topic.validate

    assert_equal ["can't be blank"], topic.errors[:title]

    assert topic.validate(:custom_context)
  end

  def test_validations_some_with_except
    Topic.validates :title, presence: { except_on: :custom_context }, length: { maximum: 10 }

    assert_raise(ActiveModel::ValidationError) do
      Topic.new.validate!
    end

    assert_raise(ActiveModel::ValidationError) do
      Topic.new(title: "A" * 11).validate!(:custom_context)
    end

    assert Topic.new.validate!(:custom_context)
  end
end
