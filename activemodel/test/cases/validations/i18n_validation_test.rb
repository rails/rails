# frozen_string_literal: true

require "cases/helper"
require "models/person"

class I18nValidationTest < ActiveModel::TestCase
  def setup
    Person.clear_validators!
    @person = person_class.new

    @old_load_path, @old_backend = I18n.load_path.dup, I18n.backend
    I18n.load_path.clear
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations("en", errors: { messages: { custom: nil } })

    @original_i18n_customize_full_message = ActiveModel::Error.i18n_customize_full_message
    ActiveModel::Error.i18n_customize_full_message = true
  end

  def teardown
    person_class.clear_validators!
    self.class.send(:remove_const, :Person)
    @person_stub = nil
    I18n.load_path.replace @old_load_path
    I18n.backend = @old_backend
    I18n.backend.reload!
    ActiveModel::Error.i18n_customize_full_message = @original_i18n_customize_full_message
  end

  def test_full_message_encoding
    I18n.backend.store_translations("en", errors: {
      messages: { too_short: "猫舌" } })
    person_class.validates_length_of :title, within: 3..5
    @person.valid?
    assert_equal ["Title 猫舌"], @person.errors.full_messages
  end

  def test_errors_full_messages_translates_human_attribute_name_for_model_attributes
    @person.errors.add(:name, "not found")
    assert_called_with(person_class, :human_attribute_name, ["name", default: "Name"], returns: "Person's name") do
      assert_equal ["Person's name not found"], @person.errors.full_messages
    end
  end

  def test_errors_full_messages_uses_format
    I18n.backend.store_translations("en", errors: { format: "Field %{attribute} %{message}" })
    @person.errors.add("name", "empty")
    assert_equal ["Field Name empty"], @person.errors.full_messages
  end

  def test_errors_full_messages_doesnt_use_attribute_format_without_config
    ActiveModel::Error.i18n_customize_full_message = false

    I18n.backend.store_translations("en", activemodel: {
      errors: { models: { person: { attributes: { name: { format: "%{message}" } } } } } })

    person = person_class.new
    assert_equal "Name cannot be blank", person.errors.full_message(:name, "cannot be blank")
    assert_equal "Name test cannot be blank", person.errors.full_message(:name_test, "cannot be blank")
  end

  def test_errors_full_messages_on_nested_error_uses_attribute_format
    ActiveModel::Error.i18n_customize_full_message = true
    I18n.backend.store_translations("en", activemodel: {
      errors: { models: { person: { attributes: { gender: "Gender" } } } },
      attributes: { "person/contacts": { gender: "Gender" } }
    })

    person = person_class.new
    error = ActiveModel::Error.new(person, :gender, "can't be blank")
    person.errors.import(error, attribute: "person[0].contacts.gender")
    assert_equal ["Gender can't be blank"], person.errors.full_messages
  end

  def test_errors_full_messages_uses_attribute_format
    ActiveModel::Error.i18n_customize_full_message = true

    I18n.backend.store_translations("en", activemodel: {
      errors: { models: { person: { attributes: { name: { format: "%{message}" } } } } } })

    person = person_class.new
    assert_equal "cannot be blank", person.errors.full_message(:name, "cannot be blank")
    assert_equal "Name test cannot be blank", person.errors.full_message(:name_test, "cannot be blank")
  end

  def test_errors_full_messages_uses_model_format
    ActiveModel::Error.i18n_customize_full_message = true

    I18n.backend.store_translations("en", activemodel: {
      errors: { models: { person: { format: "%{message}" } } } })

    person = person_class.new
    assert_equal "cannot be blank", person.errors.full_message(:name, "cannot be blank")
    assert_equal "cannot be blank", person.errors.full_message(:name_test, "cannot be blank")
  end

  def test_errors_full_messages_uses_deeply_nested_model_attributes_format
    ActiveModel::Error.i18n_customize_full_message = true

    I18n.backend.store_translations("en", activemodel: {
      errors: { models: { 'person/contacts/addresses': { attributes: { street: { format: "%{message}" } } } } } })

    person = person_class.new
    assert_equal "cannot be blank", person.errors.full_message(:'contacts/addresses.street', "cannot be blank")
    assert_equal "Contacts/addresses country cannot be blank", person.errors.full_message(:'contacts/addresses.country', "cannot be blank")
  end

  def test_errors_full_messages_uses_deeply_nested_model_model_format
    ActiveModel::Error.i18n_customize_full_message = true

    I18n.backend.store_translations("en", activemodel: {
      errors: { models: { 'person/contacts/addresses': { format: "%{message}" } } } })

    person = person_class.new
    assert_equal "cannot be blank", person.errors.full_message(:'contacts/addresses.street', "cannot be blank")
    assert_equal "cannot be blank", person.errors.full_message(:'contacts/addresses.country', "cannot be blank")
  end

  def test_errors_full_messages_with_indexed_deeply_nested_attributes_and_attributes_format
    ActiveModel::Error.i18n_customize_full_message = true

    I18n.backend.store_translations("en", activemodel: {
      errors: { models: { 'person/contacts/addresses': { attributes: { street: { format: "%{message}" } } } } } })

    person = person_class.new
    assert_equal "cannot be blank", person.errors.full_message(:'contacts[0]/addresses[123].street', "cannot be blank")
    assert_equal "Contacts/addresses country cannot be blank", person.errors.full_message(:'contacts[0]/addresses[123].country', "cannot be blank")
  end

  def test_errors_full_messages_with_indexed_deeply_nested_attributes_and_model_format
    ActiveModel::Error.i18n_customize_full_message = true

    I18n.backend.store_translations("en", activemodel: {
      errors: { models: { 'person/contacts/addresses': { format: "%{message}" } } } })

    person = person_class.new
    assert_equal "cannot be blank", person.errors.full_message(:'contacts[0]/addresses[123].street', "cannot be blank")
    assert_equal "cannot be blank", person.errors.full_message(:'contacts[0]/addresses[123].country', "cannot be blank")
  end

  def test_errors_full_messages_with_indexed_deeply_nested_attributes_and_i18n_attribute_name
    ActiveModel::Error.i18n_customize_full_message = true

    I18n.backend.store_translations("en", activemodel: {
      attributes: { 'person/contacts/addresses': { country: "Country" } }
    })

    person = person_class.new
    assert_equal "Contacts/addresses street cannot be blank", person.errors.full_message(:'contacts[0]/addresses[123].street', "cannot be blank")
    assert_equal "Country cannot be blank", person.errors.full_message(:'contacts[0]/addresses[123].country', "cannot be blank")
  end

  def test_errors_full_messages_with_indexed_deeply_nested_attributes_without_i18n_config
    ActiveModel::Error.i18n_customize_full_message = false

    I18n.backend.store_translations("en", activemodel: {
      errors: { models: { 'person/contacts/addresses': { attributes: { street: { format: "%{message}" } } } } } })

    person = person_class.new
    assert_equal "Contacts[0]/addresses[0] street cannot be blank", person.errors.full_message(:'contacts[0]/addresses[0].street', "cannot be blank")
    assert_equal "Contacts[0]/addresses[0] country cannot be blank", person.errors.full_message(:'contacts[0]/addresses[0].country', "cannot be blank")
  end

  def test_errors_full_messages_with_i18n_attribute_name_without_i18n_config
    ActiveModel::Error.i18n_customize_full_message = false

    I18n.backend.store_translations("en", activemodel: {
      attributes: { 'person/contacts[0]/addresses[0]': { country: "Country" } }
    })

    person = person_class.new
    assert_equal "Contacts[0]/addresses[0] street cannot be blank", person.errors.full_message(:'contacts[0]/addresses[0].street', "cannot be blank")
    assert_equal "Country cannot be blank", person.errors.full_message(:'contacts[0]/addresses[0].country', "cannot be blank")
  end

  # ActiveModel::Validations

  # A set of common cases for ActiveModel::Validations message generation that
  # are used to generate tests to keep things DRY
  #
  COMMON_CASES = [
    # [ case,                              validation_options,            generate_message_options]
    [ "given no options",                  {},                            {}],
    [ "given custom message",              { message: "custom" },         { message: "custom" }],
    [ "given if condition",                { if: lambda { true } },       {}],
    [ "given unless condition",            { unless: lambda { false } },  {}],
    [ "given option that is not reserved", { format: "jpg" },             { format: "jpg" }]
  ]

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_confirmation_of on generated message #{name}" do
      person_class.validates_confirmation_of :title, validation_options
      @person.title_confirmation = "foo"
      call = [:title_confirmation, :confirmation, @person, generate_message_options.merge(attribute: "Title")]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_acceptance_of on generated message #{name}" do
      person_class.validates_acceptance_of :title, validation_options.merge(allow_nil: false)
      call = [:title, :accepted, @person, generate_message_options]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_presence_of on generated message #{name}" do
      person_class.validates_presence_of :title, validation_options
      call = [:title, :blank, @person, generate_message_options]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_length_of for :within on generated message when too short #{name}" do
      person_class.validates_length_of :title, validation_options.merge(within: 3..5)
      call = [:title, :too_short, @person, generate_message_options.merge(count: 3)]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_length_of for :too_long generated message #{name}" do
      person_class.validates_length_of :title, validation_options.merge(within: 3..5)
      @person.title = "this title is too long"
      call = [:title, :too_long, @person, generate_message_options.merge(count: 5)]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_length_of for :is on generated message #{name}" do
      person_class.validates_length_of :title, validation_options.merge(is: 5)
      call = [:title, :wrong_length, @person, generate_message_options.merge(count: 5)]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_format_of on generated message #{name}" do
      person_class.validates_format_of :title, validation_options.merge(with: /\A[1-9][0-9]*\z/)
      @person.title = "72x"
      call = [:title, :invalid, @person, generate_message_options.merge(value: "72x")]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_inclusion_of on generated message #{name}" do
      person_class.validates_inclusion_of :title, validation_options.merge(in: %w(a b c))
      @person.title = "z"
      call = [:title, :inclusion, @person, generate_message_options.merge(value: "z")]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_inclusion_of using :within on generated message #{name}" do
      person_class.validates_inclusion_of :title, validation_options.merge(within: %w(a b c))
      @person.title = "z"
      call = [:title, :inclusion, @person, generate_message_options.merge(value: "z")]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_exclusion_of generated message #{name}" do
      person_class.validates_exclusion_of :title, validation_options.merge(in: %w(a b c))
      @person.title = "a"
      call = [:title, :exclusion, @person, generate_message_options.merge(value: "a")]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_exclusion_of using :within generated message #{name}" do
      person_class.validates_exclusion_of :title, validation_options.merge(within: %w(a b c))
      @person.title = "a"
      call = [:title, :exclusion, @person, generate_message_options.merge(value: "a")]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_numericality_of generated message #{name}" do
      person_class.validates_numericality_of :title, validation_options
      @person.title = "a"
      call = [:title, :not_a_number, @person, generate_message_options.merge(value: "a")]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_numericality_of for :only_integer on generated message #{name}" do
      person_class.validates_numericality_of :title, validation_options.merge(only_integer: true)
      @person.title = "0.0"
      call = [:title, :not_an_integer, @person, generate_message_options.merge(value: "0.0")]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_numericality_of for :odd on generated message #{name}" do
      person_class.validates_numericality_of :title, validation_options.merge(only_integer: true, odd: true)
      @person.title = 0
      call = [:title, :odd, @person, generate_message_options.merge(value: 0)]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  COMMON_CASES.each do |name, validation_options, generate_message_options|
    test "validates_numericality_of for :less_than on generated message #{name}" do
      person_class.validates_numericality_of :title, validation_options.merge(only_integer: true, less_than: 0)
      @person.title = 1
      call = [:title, :less_than, @person, generate_message_options.merge(value: 1, count: 0)]
      assert_called_with(ActiveModel::Error, :generate_message, call) do
        @person.valid?
        @person.errors.messages
      end
    end
  end

  # To make things DRY this macro is created to define 3 tests for every validation case.
  def self.set_expectations_for_validation(validation, error_type, &block_that_sets_validation)
    if error_type == :confirmation
      attribute = :title_confirmation
    else
      attribute = :title
    end

    test "#{validation} finds custom model key translation when #{error_type}" do
      I18n.backend.store_translations "en", activemodel: { errors: { models: { person: { attributes: { attribute => { error_type => "custom message" } } } } } }
      I18n.backend.store_translations "en", errors: { messages: { error_type => "global message" } }

      yield(@person, {})
      @person.valid?
      assert_equal ["custom message"], @person.errors[attribute]
    end

    test "#{validation} finds custom model key translation with interpolation when #{error_type}" do
      I18n.backend.store_translations "en", activemodel: { errors: { models: { person: { attributes: { attribute => { error_type => "custom message with %{extra}" } } } } } }
      I18n.backend.store_translations "en", errors: { messages: { error_type => "global message" } }

      yield(@person, { extra: "extra information" })
      @person.valid?
      assert_equal ["custom message with extra information"], @person.errors[attribute]
    end

    test "#{validation} finds global default key translation when #{error_type}" do
      I18n.backend.store_translations "en", errors: { messages: { error_type => "global message" } }

      yield(@person, {})
      @person.valid?
      assert_equal ["global message"], @person.errors[attribute]
    end
  end

  set_expectations_for_validation "validates_confirmation_of", :confirmation do |person, options_to_merge|
    person.class.validates_confirmation_of :title, options_to_merge
    person.title_confirmation = "foo"
  end

  set_expectations_for_validation "validates_acceptance_of", :accepted do |person, options_to_merge|
    person.class.validates_acceptance_of :title, options_to_merge.merge(allow_nil: false)
  end

  set_expectations_for_validation "validates_presence_of", :blank do |person, options_to_merge|
    person.class.validates_presence_of :title, options_to_merge
  end

  set_expectations_for_validation "validates_length_of", :too_short do |person, options_to_merge|
    person.class.validates_length_of :title, options_to_merge.merge(within: 3..5)
  end

  set_expectations_for_validation "validates_length_of", :too_long do |person, options_to_merge|
    person.class.validates_length_of :title, options_to_merge.merge(within: 3..5)
    person.title = "too long"
  end

  set_expectations_for_validation "validates_length_of", :wrong_length do |person, options_to_merge|
    person.class.validates_length_of :title, options_to_merge.merge(is: 5)
  end

  set_expectations_for_validation "validates_format_of", :invalid do |person, options_to_merge|
    person.class.validates_format_of :title, options_to_merge.merge(with: /\A[1-9][0-9]*\z/)
  end

  set_expectations_for_validation "validates_inclusion_of", :inclusion do |person, options_to_merge|
    person.class.validates_inclusion_of :title, options_to_merge.merge(in: %w(a b c))
  end

  set_expectations_for_validation "validates_exclusion_of", :exclusion do |person, options_to_merge|
    person.class.validates_exclusion_of :title, options_to_merge.merge(in: %w(a b c))
    person.title = "a"
  end

  set_expectations_for_validation "validates_numericality_of", :not_a_number do |person, options_to_merge|
    person.class.validates_numericality_of :title, options_to_merge
    person.title = "a"
  end

  set_expectations_for_validation "validates_numericality_of", :not_an_integer do |person, options_to_merge|
    person.class.validates_numericality_of :title, options_to_merge.merge(only_integer: true)
    person.title = "1.0"
  end

  set_expectations_for_validation "validates_numericality_of", :odd do |person, options_to_merge|
    person.class.validates_numericality_of :title, options_to_merge.merge(only_integer: true, odd: true)
    person.title = 0
  end

  set_expectations_for_validation "validates_numericality_of", :less_than do |person, options_to_merge|
    person.class.validates_numericality_of :title, options_to_merge.merge(only_integer: true, less_than: 0)
    person.title = 1
  end

  def test_validations_with_message_symbol_must_translate
    I18n.backend.store_translations "en", errors: { messages: { custom_error: "I am a custom error" } }
    person_class.validates_presence_of :title, message: :custom_error
    @person.title = nil
    @person.valid?
    assert_equal ["I am a custom error"], @person.errors[:title]
  end

  def test_validates_with_message_symbol_must_translate_per_attribute
    I18n.backend.store_translations "en", activemodel: { errors: { models: { person: { attributes: { title: { custom_error: "I am a custom error" } } } } } }
    person_class.validates_presence_of :title, message: :custom_error
    @person.title = nil
    @person.valid?
    assert_equal ["I am a custom error"], @person.errors[:title]
  end

  def test_validates_with_message_symbol_must_translate_per_model
    I18n.backend.store_translations "en", activemodel: { errors: { models: { person: { custom_error: "I am a custom error" } } } }
    person_class.validates_presence_of :title, message: :custom_error
    @person.title = nil
    @person.valid?
    assert_equal ["I am a custom error"], @person.errors[:title]
  end

  def test_validates_with_message_string
    person_class.validates_presence_of :title, message: "I am a custom error"
    @person.title = nil
    @person.valid?
    assert_equal ["I am a custom error"], @person.errors[:title]
  end

  def person_class
    @person_stub ||= self.class.const_set(:Person, Class.new(Person))
  end
end
