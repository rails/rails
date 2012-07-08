# encoding: utf-8

require 'abstract_unit'
require 'active_support/core_ext/array/clean'
require 'active_support/core_ext/hash/clean'

class CleanTest < ActiveSupport::TestCase
  def test_array_clean
    array = [1,nil,2,['',3,nil,[4,[nil],false]]]

    assert_equal [1,2,[3,[4,false]]], array.clean

    array.clean!

    assert_equal [1,2,[3,[4,false]]], array
  end

  def test_hash_clean
    hash = {:one => 1, :two => nil, :three => '', :four => 'four', :five => {:a => 'apple', :b => nil}, :six => {:c => nil, :d => '', :e => false}}

    assert_equal Hash[:one => 1, :four => 'four', :five => {:a => 'apple'}, :six => {:e => false}], hash.clean

    hash.clean!

    assert_equal Hash[:one => 1, :four => 'four', :five => { :a => 'apple' }, :six => {:e => false}], hash
  end
end
