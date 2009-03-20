require "cases/helper"
require 'models/topic'
require 'models/reply'

class I18nGenerateMessageValidationTest < Test::Unit::TestCase
  def setup
    reset_callbacks Topic
    @topic = Topic.new
    I18n.backend.store_translations :'en', {
      :activerecord => {
        :errors => {
          :messages => {
            :taken => "has already been taken",
          }
        }
      }
    }
  end

  def reset_callbacks(*models)
    models.each do |model|
      model.instance_variable_set("@validate_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
      model.instance_variable_set("@validate_on_create_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
      model.instance_variable_set("@validate_on_update_callbacks", ActiveSupport::Callbacks::CallbackChain.new)
    end
  end

  # validates_inclusion_of: generate_message(attr_name, :inclusion, :default => configuration[:message], :value => value)
  def test_generate_message_inclusion_with_default_message
    assert_equal 'is not included in the list', @topic.errors.generate_message(:title, :inclusion, :default => nil, :value => 'title')
  end

  def test_generate_message_inclusion_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :inclusion, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_exclusion_of: generate_message(attr_name, :exclusion, :default => configuration[:message], :value => value)
  def test_generate_message_exclusion_with_default_message
    assert_equal 'is reserved', @topic.errors.generate_message(:title, :exclusion, :default => nil, :value => 'title')
  end

  def test_generate_message_exclusion_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :exclusion, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_associated: generate_message(attr_name, :invalid, :default => configuration[:message], :value => value)
  # validates_format_of:  generate_message(attr_name, :invalid, :default => configuration[:message], :value => value)
  def test_generate_message_invalid_with_default_message
    assert_equal 'is invalid', @topic.errors.generate_message(:title, :invalid, :default => nil, :value => 'title')
  end

  def test_generate_message_invalid_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :invalid, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_confirmation_of: generate_message(attr_name, :confirmation, :default => configuration[:message])
  def test_generate_message_confirmation_with_default_message
    assert_equal "doesn't match confirmation", @topic.errors.generate_message(:title, :confirmation, :default => nil)
  end

  def test_generate_message_confirmation_with_custom_message
    assert_equal 'custom message', @topic.errors.generate_message(:title, :confirmation, :default => 'custom message')
  end

  # validates_acceptance_of: generate_message(attr_name, :accepted, :default => configuration[:message])
  def test_generate_message_accepted_with_default_message
    assert_equal "must be accepted", @topic.errors.generate_message(:title, :accepted, :default => nil)
  end

  def test_generate_message_accepted_with_custom_message
    assert_equal 'custom message', @topic.errors.generate_message(:title, :accepted, :default => 'custom message')
  end

  # add_on_empty: generate_message(attr, :empty, :default => custom_message)
  def test_generate_message_empty_with_default_message
    assert_equal "can't be empty", @topic.errors.generate_message(:title, :empty, :default => nil)
  end

  def test_generate_message_empty_with_custom_message
    assert_equal 'custom message', @topic.errors.generate_message(:title, :empty, :default => 'custom message')
  end

  # add_on_blank: generate_message(attr, :blank, :default => custom_message)
  def test_generate_message_blank_with_default_message
    assert_equal "can't be blank", @topic.errors.generate_message(:title, :blank, :default => nil)
  end

  def test_generate_message_blank_with_custom_message
    assert_equal 'custom message', @topic.errors.generate_message(:title, :blank, :default => 'custom message')
  end

  # validates_length_of: generate_message(attr, :too_long, :default => options[:too_long], :count => option_value.end)
  def test_generate_message_too_long_with_default_message
    assert_equal "is too long (maximum is 10 characters)", @topic.errors.generate_message(:title, :too_long, :default => nil, :count => 10)
  end

  def test_generate_message_too_long_with_custom_message
    assert_equal 'custom message 10', @topic.errors.generate_message(:title, :too_long, :default => 'custom message {{count}}', :count => 10)
  end

  # validates_length_of: generate_message(attr, :too_short, :default => options[:too_short], :count => option_value.begin)
  def test_generate_message_too_short_with_default_message
    assert_equal "is too short (minimum is 10 characters)", @topic.errors.generate_message(:title, :too_short, :default => nil, :count => 10)
  end

  def test_generate_message_too_short_with_custom_message
    assert_equal 'custom message 10', @topic.errors.generate_message(:title, :too_short, :default => 'custom message {{count}}', :count => 10)
  end

  # validates_length_of: generate_message(attr, key, :default => custom_message, :count => option_value)
  def test_generate_message_wrong_length_with_default_message
    assert_equal "is the wrong length (should be 10 characters)", @topic.errors.generate_message(:title, :wrong_length, :default => nil, :count => 10)
  end

  def test_generate_message_wrong_length_with_custom_message
    assert_equal 'custom message 10', @topic.errors.generate_message(:title, :wrong_length, :default => 'custom message {{count}}', :count => 10)
  end

  # validates_numericality_of: generate_message(attr_name, :not_a_number, :value => raw_value, :default => configuration[:message])
  def test_generate_message_not_a_number_with_default_message
    assert_equal "is not a number", @topic.errors.generate_message(:title, :not_a_number, :default => nil, :value => 'title')
  end

  def test_generate_message_not_a_number_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :not_a_number, :default => 'custom message {{value}}', :value => 'title')
  end

  # validates_numericality_of: generate_message(attr_name, option, :value => raw_value, :default => configuration[:message])
  def test_generate_message_greater_than_with_default_message
    assert_equal "must be greater than 10", @topic.errors.generate_message(:title, :greater_than, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_greater_than_or_equal_to_with_default_message
    assert_equal "must be greater than or equal to 10", @topic.errors.generate_message(:title, :greater_than_or_equal_to, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_equal_to_with_default_message
    assert_equal "must be equal to 10", @topic.errors.generate_message(:title, :equal_to, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_less_than_with_default_message
    assert_equal "must be less than 10", @topic.errors.generate_message(:title, :less_than, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_less_than_or_equal_to_with_default_message
    assert_equal "must be less than or equal to 10", @topic.errors.generate_message(:title, :less_than_or_equal_to, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_odd_with_default_message
    assert_equal "must be odd", @topic.errors.generate_message(:title, :odd, :default => nil, :value => 'title', :count => 10)
  end

  def test_generate_message_even_with_default_message
    assert_equal "must be even", @topic.errors.generate_message(:title, :even, :default => nil, :value => 'title', :count => 10)
  end

  # validates_uniqueness_of: generate_message(attr_name, :taken, :default => configuration[:message])
  def test_generate_message_taken_with_default_message
    assert_equal "has already been taken", @topic.errors.generate_message(:title, :taken, :default => nil, :value => 'title')
  end

  def test_generate_message_taken_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :taken, :default => 'custom message {{value}}', :value => 'title')
  end

end
