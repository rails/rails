# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../../../test_helper')

setup_active_record

class I18nActiveRecordMissingTest < Test::Unit::TestCase
  def setup
    store_translations(:en, :i18n => { :plural => { :keys => [:zero, :one, :other] } })
    
    I18n.backend = I18n::Backend::Chain.new(I18n.backend)
    I18n.backend.meta_class.send(:include, I18n::Backend::ActiveRecord::Missing)
    
    I18n::Backend::ActiveRecord::Translation.delete_all
  end
  
  def test_can_persist_interpolations
    translation = I18n::Backend::ActiveRecord::Translation.new \
      :key => 'foo', 
      :value => 'bar', 
      :locale => :en
    
    translation.interpolations = %w{ count name }
    translation.save
    
    assert translation.valid?
  end

  def test_lookup_persists_key
    I18n.t('foo.bar.baz')
    
    assert_equal 1, I18n::Backend::ActiveRecord::Translation.count
  end

  def test_lookup_does_not_persist_key_twice
    2.times { I18n.t('foo.bar.baz') }
    
    assert_equal 1, I18n::Backend::ActiveRecord::Translation.count
  end
  
  def test_persists_interpolation_keys_when_looked_up_directly
    I18n.t('foo.bar.baz', :cow => "lucy" )  # creates stub translation.
    
    translation_stub = I18n::Backend::ActiveRecord::Translation.locale(:en).lookup('foo.bar.baz').first
    assert translation_stub.interpolates?(:cow)
  end

  def test_creates_one_stub_per_pluralization
    I18n.t('foo', :count => 999)
    
    translations = I18n::Backend::ActiveRecord::Translation.locale(:en).find_all_by_key %w{ foo.zero foo.one foo.other }
    assert_equal 3, translations.length
  end
  
  def test_creates_no_stub_for_base_key_in_pluralization
    I18n.t('foo', :count => 999)
    
    translations = I18n::Backend::ActiveRecord::Translation.locale(:en).find_by_key %w{ foo.zero foo.one foo.other }
    assert !I18n::Backend::ActiveRecord::Translation.locale(:en).find_by_key("foo")
  end
end if defined?(ActiveRecord)
