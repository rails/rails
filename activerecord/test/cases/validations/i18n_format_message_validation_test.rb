require "cases/helper"
require 'models/topic'

class I18nFormatMessageValidationTest < ActiveRecord::TestCase
  def setup
    @topic = Topic.new(title:'')
    I18n.backend = I18n::Backend::Simple.new
  end



  def test_full_messages_format_priority_for_attribute
    repair_validations Topic do
      assert_nothing_raised { Topic.validates :title, :presence => true }
      I18n.backend.store_translations 'en', {:errors=>{:format=>"%{attribute} %{message}"},:activerecord => {:errors => {:models => {:topic=> {:attributes => {:title => {:blank => "Can't be blank", :format=>'%{message}' } } } } } } }
      assert !@topic.valid?
      assert_equal ["Can't be blank"], @topic.errors.full_messages
    end
  end

  def test_full_messages_format_priority_for_model
    repair_validations Topic do
      assert_nothing_raised { Topic.validates :title, :presence => true }
      I18n.backend.store_translations 'en', {:errors=>{:format=>"%{attribute} %{message}"},:activerecord => {:errors => {:models => {:topic=> {:attributes => {:title => {:blank => "Can't be blank"} }, :format=>'%{message}' } } } } }
      assert !@topic.valid?
      assert_equal ["Can't be blank"], @topic.errors.full_messages
    end
  end

  def test_full_messages_format_priority_default
    repair_validations Topic do
      assert_nothing_raised { Topic.validates :title, :presence => true }
      I18n.backend.store_translations 'en', {:errors=>{:format=>"%{attribute} %{message}"},:activerecord => {:errors => {:models => {:topic=> {:attributes => {:title => {:blank => "can't be blank"} } } } } } }
      assert !@topic.valid?
      assert_equal ["Title can't be blank"], @topic.errors.full_messages
    end
  end


end
