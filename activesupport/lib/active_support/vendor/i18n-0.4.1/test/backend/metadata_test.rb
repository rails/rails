# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../')); $:.uniq!
require 'test_helper'

class I18nBackendMetadataTest < Test::Unit::TestCase
  class Backend < I18n::Backend::Simple
    include I18n::Backend::Metadata
  end

  def setup
    I18n.backend = Backend.new
    store_translations(:en, :foo => 'Hi %{name}')
  end

  test "translation strings carry metadata" do
    translation = I18n.t(:foo, :name => 'David')
    assert translation.respond_to?(:translation_metadata)
    assert translation.translation_metadata.is_a?(Hash)
  end

  test "translate preserves metadata stored on original Strings" do
    store_metadata(:foo, :bar, 'bar')
    assert_equal 'bar', I18n.t(:foo, :name => 'David').translation_metadata[:bar]
  end

  test "translate preserves metadata stored on original Strings (when interpolated)" do
    store_metadata(:foo, :bar, 'bar')
    assert_equal 'bar', I18n.t(:foo, :name => 'David').translation_metadata[:bar]
  end

  test "translate adds the locale to metadata on Strings" do
    assert_equal :en, I18n.t(:foo, :name => 'David', :locale => :en).translation_metadata[:locale]
  end

  test "translate adds the key to metadata on Strings" do
    assert_equal :foo, I18n.t(:foo, :name => 'David').translation_metadata[:key]
  end
#
  test "translate adds the default to metadata on Strings" do
    assert_equal 'bar', I18n.t(:foo, :default => 'bar', :name => '').translation_metadata[:default]
  end

  test "translation adds the interpolation values to metadata on Strings" do
    assert_equal({:name => 'David'}, I18n.t(:foo, :name => 'David').translation_metadata[:values])
  end

  test "interpolation adds the original string to metadata on Strings" do
    assert_equal('Hi %{name}', I18n.t(:foo, :name => 'David').translation_metadata[:original])
  end

  test "pluralization adds the count to metadata on Strings" do
    assert_equal(1, I18n.t(:missing, :count => 1, :default => { :one => 'foo' }).translation_metadata[:count])
  end

  test "metadata works with frozen values" do
    assert_equal(1, I18n.t(:missing, :count => 1, :default => 'foo'.freeze).translation_metadata[:count])
  end
  
  protected
  
    def translations
      I18n.backend.instance_variable_get(:@translations)
    end

    def store_metadata(key, name, value)
      translations[:en][key].translation_metadata[name] = value
    end
end

