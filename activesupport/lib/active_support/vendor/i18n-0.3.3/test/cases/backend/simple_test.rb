# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class I18nBackendSimpleTest < Test::Unit::TestCase
  def setup
    I18n.backend = I18n::Backend::Simple.new
    I18n.load_path = [locales_dir + '/en.yml']
  end

  # useful because this way we can use the backend with no key for interpolation/pluralization
  define_method "test simple backend lookup: given nil as a key it returns nil" do
    assert_nil I18n.backend.send(:lookup, :en, nil)
  end
  
  # loading translations
      
  define_method "test simple load_translations: given an unknown file type it raises I18n::UnknownFileType" do
    assert_raises(I18n::UnknownFileType) { I18n.backend.load_translations("#{locales_dir}/en.xml") }
  end
  
  define_method "test simple load_translations: given a Ruby file name it does not raise anything" do
    assert_nothing_raised { I18n.backend.load_translations("#{locales_dir}/en.rb") }
  end
  
  define_method "test simple load_rb: loads data from a Ruby file" do
    data = I18n.backend.send(:load_rb, "#{locales_dir}/en.rb")
    assert_equal({ :en => { :fuh => { :bah => 'bas' } } }, data)
  end

  define_method "test simple load_yml: loads data from a YAML file" do
    data = I18n.backend.send(:load_yml, "#{locales_dir}/en.yml")
    assert_equal({ 'en' => { 'foo' => { 'bar' => 'baz' } } }, data)
  end

  define_method "test simple load_translations: loads data from known file formats" do
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.load_translations("#{locales_dir}/en.rb", "#{locales_dir}/en.yml")
    expected = { :en => { :fuh => { :bah => "bas" }, :foo => { :bar => "baz" } } }
    assert_equal expected, translations
  end
  
  # storing translations

  define_method "test simple store_translations: stores translations, ... no, really :-)" do
    I18n.backend.store_translations :'en', :foo => 'bar'
    assert_equal Hash[:'en', {:foo => 'bar'}], translations
  end

  define_method "test simple store_translations: deep_merges with existing translations" do
    I18n.backend.store_translations :'en', :foo => {:bar => 'bar'}
    I18n.backend.store_translations :'en', :foo => {:baz => 'baz'}
    assert_equal Hash[:'en', {:foo => {:bar => 'bar', :baz => 'baz'}}], translations
  end

  define_method "test simple store_translations: converts the given locale to a Symbol" do
    I18n.backend.store_translations 'en', :foo => 'bar'
    assert_equal Hash[:'en', {:foo => 'bar'}], translations
  end

  define_method "test simple store_translations: converts keys to Symbols" do
    I18n.backend.store_translations 'en', 'foo' => {'bar' => 'bar', 'baz' => 'baz'}
    assert_equal Hash[:'en', {:foo => {:bar => 'bar', :baz => 'baz'}}], translations
  end
  
  # reloading translations

  define_method "test simple reload_translations: unloads translations" do
    I18n.backend.reload!
    assert_nil translations
  end

  define_method "test simple reload_translations: uninitializes the backend" do
    I18n.backend.reload!
    assert_equal I18n.backend.initialized?, false
  end
end
