require 'cases/helper'

class SuperUser
  extend ActiveModel::Translation
end

class User < SuperUser
end

class ActiveModelI18nTests < ActiveModel::TestCase

  def setup
    I18n.backend = I18n::Backend::Simple.new
  end
  
  def test_translated_model_attributes
    I18n.backend.store_translations 'en', :activemodel => {:attributes => {:super_user => {:name => 'super_user name attribute'} } }
    assert_equal 'super_user name attribute', SuperUser.human_attribute_name('name')
  end
  
  def test_translated_model_attributes_with_symbols
    I18n.backend.store_translations 'en', :activemodel => {:attributes => {:super_user => {:name => 'super_user name attribute'} } }
    assert_equal 'super_user name attribute', SuperUser.human_attribute_name(:name)
  end

  def test_translated_model_attributes_with_ancestor
    I18n.backend.store_translations 'en', :activemodel => {:attributes => {:user => {:name => 'user name attribute'} } }
    assert_equal 'user name attribute', User.human_attribute_name('name')
  end

  def test_translated_model_attributes_with_ancestors_fallback
    I18n.backend.store_translations 'en', :activemodel => {:attributes => {:super_user => {:name => 'super_user name attribute'} } }
    assert_equal 'super_user name attribute', User.human_attribute_name('name')
  end

  def test_translated_model_names
    I18n.backend.store_translations 'en', :activemodel => {:models => {:super_user => 'super_user model'} }
    assert_equal 'super_user model', SuperUser.model_name.human
  end

  def test_translated_model_names_with_sti
    I18n.backend.store_translations 'en', :activemodel => {:models => {:user => 'user model'} }
    assert_equal 'user model', User.model_name.human
  end

  def test_translated_model_names_with_ancestors_fallback
    I18n.backend.store_translations 'en', :activemodel => {:models => {:super_user => 'super_user model'} }
    assert_equal 'super_user model', User.model_name.human
  end
end

