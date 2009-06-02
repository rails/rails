require "cases/helper"
require 'cases/tests_database'

require 'models/person'

class I18nGenerateMessageValidationTest < Test::Unit::TestCase
  def setup
    reset_callbacks Person
    @person = Person.new

    @old_load_path, @old_backend = I18n.load_path, I18n.backend
    I18n.load_path.clear
    I18n.backend = I18n::Backend::Simple.new

    I18n.backend.store_translations :'en', {
      :activemodel => {
        :errors => {
          :messages => {
            :inclusion => "is not included in the list",
            :exclusion => "is reserved",
            :invalid => "is invalid",
            :confirmation => "doesn't match confirmation",
            :accepted  => "must be accepted",
            :empty => "can't be empty",
            :blank => "can't be blank",
            :too_long => "is too long (maximum is {{count}} characters)",
            :too_short => "is too short (minimum is {{count}} characters)",
            :wrong_length => "is the wrong length (should be {{count}} characters)",
            :not_a_number => "is not a number",
            :greater_than => "must be greater than {{count}}",
            :greater_than_or_equal_to => "must be greater than or equal to {{count}}",
            :equal_to => "must be equal to {{count}}",
            :less_than => "must be less than {{count}}",
            :less_than_or_equal_to => "must be less than or equal to {{count}}",
            :odd => "must be odd",
            :even => "must be even"
          }
        }
      }
    }
  end

  def teardown
    I18n.load_path.replace @old_load_path
    I18n.backend = @old_backend
  end

  def reset_callbacks(*models)
    models.each do |model|
      model.instance_variable_set("@validate_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
    end
  end

  # validates_inclusion_of: generate_message(attr_name, :inclusion, :default => configuration[:message], :value => value)
  def test_generate_message_inclusion_with_default_message
    assert_equal 'is not included in the list', @person.errors.generate_message(:title, :inclusion, :default => nil, :value => 'title')
  end

  def test_generate_message_inclusion_with_custom_message
    assert_equal 'custom message title', @person.errors.generate_message(:title, :inclusion, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_exclusion_of: generate_message(attr_name, :exclusion, :default => configuration[:message], :value => value)
  def test_generate_message_exclusion_with_default_message
    assert_equal 'is reserved', @person.errors.generate_message(:title, :exclusion, :default => nil, :value => 'title')
  end

  def test_generate_message_exclusion_with_custom_message
    assert_equal 'custom message title', @person.errors.generate_message(:title, :exclusion, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_associated: generate_message(attr_name, :invalid, :default => configuration[:message], :value => value)
  # validates_format_of:  generate_message(attr_name, :invalid, :default => configuration[:message], :value => value)
  def test_generate_message_invalid_with_default_message
    assert_equal 'is invalid', @person.errors.generate_message(:title, :invalid, :default => nil, :value => 'title')
  end

  def test_generate_message_invalid_with_custom_message
    assert_equal 'custom message title', @person.errors.generate_message(:title, :invalid, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_confirmation_of: generate_message(attr_name, :confirmation, :default => configuration[:message])
  def test_generate_message_confirmation_with_default_message
    assert_equal "doesn't match confirmation", @person.errors.generate_message(:title, :confirmation, :default => nil)
  end

  def test_generate_message_confirmation_with_custom_message
    assert_equal 'custom message', @person.errors.generate_message(:title, :confirmation, :default => 'custom message')
  end

  # validates_acceptance_of: generate_message(attr_name, :accepted, :default => configuration[:message])
  def test_generate_message_accepted_with_default_message
    assert_equal "must be accepted", @person.errors.generate_message(:title, :accepted, :default => nil)
  end

  def test_generate_message_accepted_with_custom_message
    assert_equal 'custom message', @person.errors.generate_message(:title, :accepted, :default => 'custom message')
  end

  # add_on_empty: generate_message(attr, :empty, :default => custom_message)
  def test_generate_message_empty_with_default_message
    assert_equal "can't be empty", @person.errors.generate_message(:title, :empty, :default => nil)
  end

  def test_generate_message_empty_with_custom_message
    assert_equal 'custom message', @person.errors.generate_message(:title, :empty, :default => 'custom message')
  end

  # add_on_blank: generate_message(attr, :blank, :default => custom_message)
  def test_generate_message_blank_with_default_message
    assert_equal "can't be blank", @person.errors.generate_message(:title, :blank, :default => nil)
  end

  def test_generate_message_blank_with_custom_message
    assert_equal 'custom message', @person.errors.generate_message(:title, :blank, :default => 'custom message')
  end

  # validates_length_of: generate_message(attr, :too_long, :default => options[:too_long], :count => option_value.end)
  def test_generate_message_too_long_with_default_message
    assert_equal "is too long (maximum is 10 characters)", @person.errors.generate_message(:title, :too_long, :default => nil, :count => 10)
  end

  def test_generate_message_too_long_with_custom_message
    assert_equal 'custom message 10', @person.errors.generate_message(:title, :too_long, :default => 'custom message {{count}}', :count => 10)
  end

  # validates_length_of: generate_message(attr, :too_short, :default => options[:too_short], :count => option_value.begin)
  def test_generate_message_too_short_with_default_message
    assert_equal "is too short (minimum is 10 characters)", @person.errors.generate_message(:title, :too_short, :default => nil, :count => 10)
  end

  def test_generate_message_too_short_with_custom_message
    assert_equal 'custom message 10', @person.errors.generate_message(:title, :too_short, :default => 'custom message {{count}}', :count => 10)
  end

  # validates_length_of: generate_message(attr, key, :default => custom_message, :count => option_value)
  def test_generate_message_wrong_length_with_default_message
    assert_equal "is the wrong length (should be 10 characters)", @person.errors.generate_message(:title, :wrong_length, :default => nil, :count => 10)
  end

  def test_generate_message_wrong_length_with_custom_message
    assert_equal 'custom message 10', @person.errors.generate_message(:title, :wrong_length, :default => 'custom message {{count}}', :count => 10)
  end

  # validates_numericality_of: generate_message(attr_name, :not_a_number, :value => raw_value, :default => configuration[:message])
  def test_generate_message_not_a_number_with_default_message
    assert_equal "is not a number", @person.errors.generate_message(:title, :not_a_number, :default => nil, :value => 'title')
  end

  def test_generate_message_not_a_number_with_custom_message
    assert_equal 'custom message title', @person.errors.generate_message(:title, :not_a_number, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_numericality_of: generate_message(attr_name, option, :value => raw_value, :default => configuration[:message])
  def test_generate_message_greater_than_with_default_message
    assert_equal "must be greater than 10", @person.errors.generate_message(:title, :greater_than, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_greater_than_or_equal_to_with_default_message
    assert_equal "must be greater than or equal to 10", @person.errors.generate_message(:title, :greater_than_or_equal_to, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_equal_to_with_default_message
    assert_equal "must be equal to 10", @person.errors.generate_message(:title, :equal_to, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_less_than_with_default_message
    assert_equal "must be less than 10", @person.errors.generate_message(:title, :less_than, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_less_than_or_equal_to_with_default_message
    assert_equal "must be less than or equal to 10", @person.errors.generate_message(:title, :less_than_or_equal_to, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_odd_with_default_message
    assert_equal "must be odd", @person.errors.generate_message(:title, :odd, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_even_with_default_message
    assert_equal "must be even", @person.errors.generate_message(:title, :even, :default => nil, :value => 'title', :count => 10)
  end
end
