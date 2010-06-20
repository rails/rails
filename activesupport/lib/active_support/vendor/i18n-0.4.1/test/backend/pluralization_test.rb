# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../')); $:.uniq!
require 'test_helper'

class I18nBackendPluralizationTest < Test::Unit::TestCase
  class Backend < I18n::Backend::Simple
    include I18n::Backend::Pluralization
    include I18n::Backend::Fallbacks
  end

  def setup
    I18n.backend = Backend.new
    @rule = lambda { |n| n == 1 ? :one : n == 0 || (2..10).include?(n % 100) ? :few : (11..19).include?(n % 100) ? :many : :other }
    store_translations(:xx, :i18n => { :plural => { :rule => @rule } })
    @entry = { :zero => 'zero', :one => 'one', :few => 'few', :many => 'many', :other => 'other' }
  end

  test "pluralization picks a pluralizer from :'i18n.pluralize'" do
    assert_equal @rule, I18n.backend.send(:pluralizer, :xx)
  end

  test "pluralization picks :one for 1" do
    assert_equal 'one', I18n.t(:count => 1, :default => @entry, :locale => :xx)
  end

  test "pluralization picks :few for 2" do
    assert_equal 'few', I18n.t(:count => 2, :default => @entry, :locale => :xx)
  end

  test "pluralization picks :many for 11" do
    assert_equal 'many', I18n.t(:count => 11, :default => @entry, :locale => :xx)
  end

  test "pluralization picks zero for 0 if the key is contained in the data" do
    assert_equal 'zero', I18n.t(:count => 0, :default => @entry, :locale => :xx)
  end

  test "pluralization picks few for 0 if the key is not contained in the data" do
    @entry.delete(:zero)
    assert_equal 'few', I18n.t(:count => 0, :default => @entry, :locale => :xx)
  end

  test "Fallbacks can pick up rules from fallback locales, too" do
    assert_equal @rule, I18n.backend.send(:pluralizer, :'xx-XX')
  end
end
