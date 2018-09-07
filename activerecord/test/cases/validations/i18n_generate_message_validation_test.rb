# frozen_string_literal: true

require "cases/helper"
require "models/topic"

class I18nGenerateMessageValidationTest < ActiveRecord::TestCase
  def setup
    Topic.clear_validators!
    @topic = Topic.new
    I18n.backend = I18n::Backend::Simple.new
  end

  def reset_i18n_load_path
    @old_load_path, @old_backend = I18n.load_path.dup, I18n.backend
    I18n.load_path.clear
    I18n.backend = I18n::Backend::Simple.new
    yield
  ensure
    I18n.load_path.replace @old_load_path
    I18n.backend = @old_backend
  end

  # validates_associated: generate_message(attr_name, :invalid, :message => custom_message, :value => value)
  def test_generate_message_invalid_with_default_message
    assert_equal "is invalid", @topic.errors.generate_message(:title, :invalid, value: "title")
  end

  def test_generate_message_invalid_with_custom_message
    assert_equal "custom message title", @topic.errors.generate_message(:title, :invalid, message: "custom message %{value}", value: "title")
  end

  # validates_uniqueness_of: generate_message(attr_name, :taken, :message => custom_message)
  def test_generate_message_taken_with_default_message
    assert_equal "has already been taken", @topic.errors.generate_message(:title, :taken, value: "title")
  end

  def test_generate_message_taken_with_custom_message
    assert_equal "custom message title", @topic.errors.generate_message(:title, :taken, message: "custom message %{value}", value: "title")
  end

  # ActiveRecord#RecordInvalid exception

  test "RecordInvalid exception can be localized" do
    topic = Topic.new
    topic.errors.add(:title, :invalid)
    topic.errors.add(:title, :blank)
    assert_equal "Validation failed: Title is invalid, Title can't be blank", ActiveRecord::RecordInvalid.new(topic).message
  end

  test "RecordInvalid exception translation falls back to the :errors namespace" do
    reset_i18n_load_path do
      I18n.backend.store_translations "en", errors: { messages: { record_invalid: "fallback message" } }
      topic = Topic.new
      topic.errors.add(:title, :blank)
      assert_equal "fallback message", ActiveRecord::RecordInvalid.new(topic).message
    end
  end

  test "translation for 'taken' can be overridden" do
    reset_i18n_load_path do
      I18n.backend.store_translations "en", errors: { attributes: { title: { taken: "Custom taken message" } } }
      assert_equal "Custom taken message", @topic.errors.generate_message(:title, :taken, value: "title")
    end
  end

  test "translation for 'taken' can be overridden in activerecord scope" do
    reset_i18n_load_path do
      I18n.backend.store_translations "en", activerecord: { errors: { messages: { taken: "Custom taken message" } } }
      assert_equal "Custom taken message", @topic.errors.generate_message(:title, :taken, value: "title")
    end
  end

  test "translation for 'taken' can be overridden in activerecord model scope" do
    reset_i18n_load_path do
      I18n.backend.store_translations "en", activerecord: { errors: { models: { topic: { taken: "Custom taken message" } } } }
      assert_equal "Custom taken message", @topic.errors.generate_message(:title, :taken, value: "title")
    end
  end

  test "translation for 'taken' can be overridden in activerecord attributes scope" do
    reset_i18n_load_path do
      I18n.backend.store_translations "en", activerecord: { errors: { models: { topic: { attributes: { title: { taken: "Custom taken message" } } } } } }
      assert_equal "Custom taken message", @topic.errors.generate_message(:title, :taken, value: "title")
    end
  end
end
