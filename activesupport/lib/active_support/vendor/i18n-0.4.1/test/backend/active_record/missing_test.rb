# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../../')); $:.uniq!
require 'test_helper'

setup_active_record

class I18nActiveRecordMissingTest < Test::Unit::TestCase
  def setup
    store_translations(:en, :i18n => { :plural => { :keys => [:zero, :one, :other] } })
    
    I18n.backend = I18n::Backend::Chain.new(I18n.backend)
    I18n.backend.meta_class.send(:include, I18n::Backend::ActiveRecord::Missing)
    
    I18n::Backend::ActiveRecord::Translation.delete_all
  end
  
  test "can persist interpolations" do
    translation = I18n::Backend::ActiveRecord::Translation.new(:key => 'foo', :value => 'bar', :locale => :en)
    translation.interpolations = %w(count name)
    translation.save
    assert translation.valid?
  end

  test "lookup persists the key" do
    I18n.t('foo.bar.baz')
    assert_equal 1, I18n::Backend::ActiveRecord::Translation.count
  end

  test "lookup does not persist the key twice" do
    2.times { I18n.t('foo.bar.baz') }
    assert_equal 1, I18n::Backend::ActiveRecord::Translation.count
  end
  
  test "lookup persists interpolation keys when looked up directly" do
    I18n.t('foo.bar.baz', :cow => "lucy" )  # creates stub translation.
    translation_stub = I18n::Backend::ActiveRecord::Translation.locale(:en).lookup('foo.bar.baz').first
    assert translation_stub.interpolates?(:cow)
  end

  test "creates one stub per pluralization" do
    I18n.t('foo', :count => 999)
    translations = I18n::Backend::ActiveRecord::Translation.locale(:en).find_all_by_key %w{ foo.zero foo.one foo.other }
    assert_equal 3, translations.length
  end

  test "creates no stub for base key in pluralization" do
    I18n.t('foo', :count => 999)
    translations = I18n::Backend::ActiveRecord::Translation.locale(:en).find_by_key %w{ foo.zero foo.one foo.other }
    assert !I18n::Backend::ActiveRecord::Translation.locale(:en).find_by_key("foo")
  end
end if defined?(ActiveRecord)
