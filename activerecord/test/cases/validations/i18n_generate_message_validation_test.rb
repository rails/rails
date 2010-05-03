require "cases/helper"
require 'models/topic'
require 'models/reply'

class I18nGenerateMessageValidationTest < ActiveRecord::TestCase
  def setup
    Topic.reset_callbacks(:validate)
    @topic = Topic.new
    I18n.backend = I18n::Backend::Simple.new
  end

  # validates_associated: generate_message(attr_name, :invalid, :default => configuration[:message], :value => value)
  def test_generate_message_invalid_with_default_message
    assert_equal 'is invalid', @topic.errors.generate_message(:title, :invalid, :default => nil, :value => 'title')
  end

  def test_generate_message_invalid_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :invalid, :default => 'custom message %{value}', :value => 'title')
  end

  # validates_uniqueness_of: generate_message(attr_name, :taken, :default => configuration[:message])
  def test_generate_message_taken_with_default_message
    assert_equal "has already been taken", @topic.errors.generate_message(:title, :taken, :default => nil, :value => 'title')
  end

  def test_generate_message_taken_with_custom_message
    assert_equal 'custom message title', @topic.errors.generate_message(:title, :taken, :default => 'custom message %{value}', :value => 'title')
  end

  # ActiveRecord#RecordInvalid exception

  test "RecordInvalid exception can be localized" do
    topic = Topic.new
    topic.errors.add(:title, :invalid)
    topic.errors.add(:title, :blank)
    assert_equal "Validation failed: Title is invalid, Title can't be blank", ActiveRecord::RecordInvalid.new(topic).message
  end

end
