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

  # validates_uniqueness_of: generate_message(attr_name, :taken, :default => configuration[:message])
  def test_generate_message_taken_with_default_message
    assert_equal "has already been taken", @topic.errors.generate_message(:title, :taken, :default => nil, :value => 'title')
  end

  def test_generate_message_taken_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :taken, :default => 'custom message {{value}}', :value => 'title')
  end

end
