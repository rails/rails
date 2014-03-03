require "cases/helper"
require 'models/topic'

class I18nFormatMessageValidationTest < ActiveRecord::TestCase
  def setup
    @topic = Topic.new
    I18n.backend = I18n::Backend::Simple.new
  end

  def  test_error_message_format_with_attribute
    assert_equal :"errors.format", @topic.errors.error_message_format(:title)
  end

  def test_i18n_priority_format_with_attribute
    expected_keys = [:"errors.format", :"activerecord.errors.models.topic.format", :"activerecord.errors.models.topic.attributes.title.format"]
    assert_equal expected_keys, @topic.errors.i18n_priority_format(:title)
  end

  def test_error_message_format_priority_key_for_attribute
    I18n.backend.store_translations 'en', {:activerecord => {:errors => {:models => {:topic=> {:attributes => {:title => {:blank => "Can't be blank", :format=>'%{message}' } } } } } } }
    assert_equal :"activerecord.errors.models.topic.attributes.title.format", @topic.errors.error_message_format(:title)
  end

  def test_error_message_format_priority_key_for_model
    I18n.backend.store_translations 'en', {:activerecord => {:errors => {:models => {:topic=> {:attributes => {:title => {:blank => "Can't be blank" } }, :format=>'%{message}' } } } } }
    assert_equal :"activerecord.errors.models.topic.format", @topic.errors.error_message_format(:title)
  end


end
