# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../')); $:.uniq!

require 'test_helper'
require 'i18n/core_ext/hash'

class I18nCoreExtHashInterpolationTest < Test::Unit::TestCase
  test "#deep_symbolize_keys" do
    hash = { 'foo' => { 'bar' => { 'baz' => 'bar' } } }
    expected = { :foo => { :bar => { :baz => 'bar' } } }
    assert_equal expected, hash.deep_symbolize_keys
  end

  test "#slice" do
    hash = { :foo => 'bar',  :baz => 'bar' }
    expected = { :foo => 'bar' }
    assert_equal expected, hash.slice(:foo)
  end

  test "#except" do
    hash = { :foo => 'bar',  :baz => 'bar' }
    expected = { :foo => 'bar' }
    assert_equal expected, hash.except(:baz)
  end

  test "#deep_merge!" do
    hash = { :foo => { :bar => { :baz => 'bar' } }, :baz => 'bar' }
    hash.deep_merge!(:foo => { :bar => { :baz => 'foo' } })

    expected = { :foo => { :bar => { :baz => 'foo' } }, :baz => 'bar' }
    assert_equal expected, hash
  end
end
