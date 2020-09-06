# frozen_string_literal: true

require 'cases/helper'
require 'models/topic'
require 'models/reply'

class ActiveRecordI18nTests < ActiveRecord::TestCase
  def setup
    I18n.backend = I18n::Backend::Simple.new
  end

  def test_translated_model_attributes
    I18n.backend.store_translations 'en', activerecord: { attributes: { topic: { title: 'topic title attribute' } } }
    assert_equal 'topic title attribute', Topic.human_attribute_name('title')
  end

  def test_translated_model_attributes_with_symbols
    I18n.backend.store_translations 'en', activerecord: { attributes: { topic: { title: 'topic title attribute' } } }
    assert_equal 'topic title attribute', Topic.human_attribute_name(:title)
  end

  def test_translated_model_attributes_with_sti
    I18n.backend.store_translations 'en', activerecord: { attributes: { reply: { title: 'reply title attribute' } } }
    assert_equal 'reply title attribute', Reply.human_attribute_name('title')
  end

  def test_translated_model_attributes_with_sti_fallback
    I18n.backend.store_translations 'en', activerecord: { attributes: { topic: { title: 'topic title attribute' } } }
    assert_equal 'topic title attribute', Reply.human_attribute_name('title')
  end

  def test_translated_model_names
    I18n.backend.store_translations 'en', activerecord: { models: { topic: 'topic model' } }
    assert_equal 'topic model', Topic.model_name.human
  end

  def test_translated_model_names_with_sti
    I18n.backend.store_translations 'en', activerecord: { models: { reply: 'reply model' } }
    assert_equal 'reply model', Reply.model_name.human
  end

  def test_translated_model_names_with_sti_fallback
    I18n.backend.store_translations 'en', activerecord: { models: { topic: 'topic model' } }
    assert_equal 'topic model', Reply.model_name.human
  end
end
