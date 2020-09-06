# frozen_string_literal: true

require 'cases/helper'

require 'models/person'

class I18nGenerateMessageValidationTest < ActiveModel::TestCase
  def setup
    Person.clear_validators!
    @person = Person.new
  end

  # validates_inclusion_of: generate_message(attr_name, :inclusion, message: custom_message, value: value)
  def test_generate_message_inclusion_with_default_message
    assert_equal 'is not included in the list', @person.errors.generate_message(:title, :inclusion, value: 'title')
  end

  def test_generate_message_inclusion_with_custom_message
    assert_equal 'custom message title', @person.errors.generate_message(:title, :inclusion, message: 'custom message %{value}', value: 'title')
  end

  # validates_exclusion_of: generate_message(attr_name, :exclusion, message: custom_message, value: value)
  def test_generate_message_exclusion_with_default_message
    assert_equal 'is reserved', @person.errors.generate_message(:title, :exclusion, value: 'title')
  end

  def test_generate_message_exclusion_with_custom_message
    assert_equal 'custom message title', @person.errors.generate_message(:title, :exclusion, message: 'custom message %{value}', value: 'title')
  end

  # validates_format_of:  generate_message(attr_name, :invalid, message: custom_message, value: value)
  def test_generate_message_invalid_with_default_message
    assert_equal 'is invalid', @person.errors.generate_message(:title, :invalid, value: 'title')
  end

  def test_generate_message_invalid_with_custom_message
    assert_equal 'custom message title', @person.errors.generate_message(:title, :invalid, message: 'custom message %{value}', value: 'title')
  end

  # validates_confirmation_of: generate_message(attr_name, :confirmation, message: custom_message)
  def test_generate_message_confirmation_with_default_message
    assert_equal "doesn't match Title", @person.errors.generate_message(:title, :confirmation)
  end

  def test_generate_message_confirmation_with_custom_message
    assert_equal 'custom message', @person.errors.generate_message(:title, :confirmation, message: 'custom message')
  end

  # validates_acceptance_of: generate_message(attr_name, :accepted, message: custom_message)
  def test_generate_message_accepted_with_default_message
    assert_equal 'must be accepted', @person.errors.generate_message(:title, :accepted)
  end

  def test_generate_message_accepted_with_custom_message
    assert_equal 'custom message', @person.errors.generate_message(:title, :accepted, message: 'custom message')
  end

  # add_on_empty: generate_message(attr, :empty, message: custom_message)
  def test_generate_message_empty_with_default_message
    assert_equal "can't be empty", @person.errors.generate_message(:title, :empty)
  end

  def test_generate_message_empty_with_custom_message
    assert_equal 'custom message', @person.errors.generate_message(:title, :empty, message: 'custom message')
  end

  # validates_presence_of: generate_message(attr, :blank, message: custom_message)
  def test_generate_message_blank_with_default_message
    assert_equal "can't be blank", @person.errors.generate_message(:title, :blank)
  end

  def test_generate_message_blank_with_custom_message
    assert_equal 'custom message', @person.errors.generate_message(:title, :blank, message: 'custom message')
  end

  # validates_length_of: generate_message(attr, :too_long, message: custom_message, count: option_value.end)
  def test_generate_message_too_long_with_default_message_plural
    assert_equal 'is too long (maximum is 10 characters)', @person.errors.generate_message(:title, :too_long, count: 10)
  end

  def test_generate_message_too_long_with_default_message_singular
    assert_equal 'is too long (maximum is 1 character)', @person.errors.generate_message(:title, :too_long, count: 1)
  end

  def test_generate_message_too_long_with_custom_message
    assert_equal 'custom message 10', @person.errors.generate_message(:title, :too_long, message: 'custom message %{count}', count: 10)
  end

  # validates_length_of: generate_message(attr, :too_short, default: custom_message, count: option_value.begin)
  def test_generate_message_too_short_with_default_message_plural
    assert_equal 'is too short (minimum is 10 characters)', @person.errors.generate_message(:title, :too_short, count: 10)
  end

  def test_generate_message_too_short_with_default_message_singular
    assert_equal 'is too short (minimum is 1 character)', @person.errors.generate_message(:title, :too_short, count: 1)
  end

  def test_generate_message_too_short_with_custom_message
    assert_equal 'custom message 10', @person.errors.generate_message(:title, :too_short, message: 'custom message %{count}', count: 10)
  end

  # validates_length_of: generate_message(attr, :wrong_length, message: custom_message, count: option_value)
  def test_generate_message_wrong_length_with_default_message_plural
    assert_equal 'is the wrong length (should be 10 characters)', @person.errors.generate_message(:title, :wrong_length, count: 10)
  end

  def test_generate_message_wrong_length_with_default_message_singular
    assert_equal 'is the wrong length (should be 1 character)', @person.errors.generate_message(:title, :wrong_length, count: 1)
  end

  def test_generate_message_wrong_length_with_custom_message
    assert_equal 'custom message 10', @person.errors.generate_message(:title, :wrong_length, message: 'custom message %{count}', count: 10)
  end

  # validates_numericality_of: generate_message(attr_name, :not_a_number, value: raw_value, message: custom_message)
  def test_generate_message_not_a_number_with_default_message
    assert_equal 'is not a number', @person.errors.generate_message(:title, :not_a_number, value: 'title')
  end

  def test_generate_message_not_a_number_with_custom_message
    assert_equal 'custom message title', @person.errors.generate_message(:title, :not_a_number, message: 'custom message %{value}', value: 'title')
  end

  # validates_numericality_of: generate_message(attr_name, option, value: raw_value, default: custom_message)
  def test_generate_message_greater_than_with_default_message
    assert_equal 'must be greater than 10', @person.errors.generate_message(:title, :greater_than, value: 'title', count: 10)
  end

  def test_generate_message_greater_than_or_equal_to_with_default_message
    assert_equal 'must be greater than or equal to 10', @person.errors.generate_message(:title, :greater_than_or_equal_to, value: 'title', count: 10)
  end

  def test_generate_message_equal_to_with_default_message
    assert_equal 'must be equal to 10', @person.errors.generate_message(:title, :equal_to, value: 'title', count: 10)
  end

  def test_generate_message_less_than_with_default_message
    assert_equal 'must be less than 10', @person.errors.generate_message(:title, :less_than, value: 'title', count: 10)
  end

  def test_generate_message_less_than_or_equal_to_with_default_message
    assert_equal 'must be less than or equal to 10', @person.errors.generate_message(:title, :less_than_or_equal_to, value: 'title', count: 10)
  end

  def test_generate_message_odd_with_default_message
    assert_equal 'must be odd', @person.errors.generate_message(:title, :odd, value: 'title', count: 10)
  end

  def test_generate_message_even_with_default_message
    assert_equal 'must be even', @person.errors.generate_message(:title, :even, value: 'title', count: 10)
  end
end
