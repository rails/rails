require "cases/helper"
require 'models/topic'
require 'models/reply'

class NumericData < ActiveRecord::Base
  self.table_name = 'numeric_data'
end

class ActiveRecordI18nTests < ActiveRecord::TestCase

  def setup
    I18n.backend = I18n::Backend::Simple.new
  end

  def test_translated_model_attributes
    I18n.backend.store_translations 'en', :activerecord => {:attributes => {:topic => {:title => 'topic title attribute'} } }
    assert_equal 'topic title attribute', Topic.human_attribute_name('title')
  end

  def test_translated_model_attributes_with_symbols
    I18n.backend.store_translations 'en', :activerecord => {:attributes => {:topic => {:title => 'topic title attribute'} } }
    assert_equal 'topic title attribute', Topic.human_attribute_name(:title)
  end

  def test_translated_model_attributes_with_sti
    I18n.backend.store_translations 'en', :activerecord => {:attributes => {:reply => {:title => 'reply title attribute'} } }
    assert_equal 'reply title attribute', Reply.human_attribute_name('title')
  end

  def test_translated_model_attributes_with_sti_fallback
    I18n.backend.store_translations 'en', :activerecord => {:attributes => {:topic => {:title => 'topic title attribute'} } }
    assert_equal 'topic title attribute', Reply.human_attribute_name('title')
  end

  def test_translated_model_names
    I18n.backend.store_translations 'en', :activerecord => {:models => {:topic => 'topic model'} }
    assert_equal 'topic model', Topic.model_name.human
  end

  def test_translated_model_names_with_sti
    I18n.backend.store_translations 'en', :activerecord => {:models => {:reply => 'reply model'} }
    assert_equal 'reply model', Reply.model_name.human
  end

  def test_translated_model_names_with_sti_fallback
    I18n.backend.store_translations 'en', :activerecord => {:models => {:topic => 'topic model'} }
    assert_equal 'topic model', Reply.model_name.human
  end
  
  def test_default_number_input
    numeric_data = NumericData.new
    numeric_data.attributes = { "bank_balance" => "1.234" }
    numeric_data.save
    assert_equal(1.234, numeric_data.bank_balance)
  end

  def test_localized_number_input
    I18n.backend.store_translations 'de', :number => {:format => {:separator => ',', :delimiter => ''} }
    numeric_data = NumericData.new
    I18n.with_locale(:de) do
      numeric_data.attributes = { "bank_balance" => "1,234" }
      numeric_data.save
    end
    assert_equal(1.234, numeric_data.bank_balance)
  end

  def test_localized_number_input_with_delimiter
    I18n.backend.store_translations 'de', :number => {:format => {:separator => ',', :delimiter => '.'} }
    numeric_data = NumericData.new
    I18n.with_locale(:de) do
      numeric_data.attributes = { "bank_balance" => "1.234,5" }
      numeric_data.save
    end
    assert_equal(1234.5, numeric_data.bank_balance)
  end
end
