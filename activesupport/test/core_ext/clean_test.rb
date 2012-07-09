# encoding: utf-8

require 'abstract_unit'
require 'active_support/core_ext/enumerable'

class CleanTest < ActiveSupport::TestCase
  def test_array_clean
    array = [1,nil,2,['',3,nil,[4,[nil],false]]]

    assert_equal [1,2,[3,[4,false]]], array.clean

    array.clean!

    assert_equal [1,2,[3,[4,false]]], array

    assert_equal [true,false], [true,false].clean
    assert_equal [1,2,9..12], [1,2,9..12].clean
  end

  def test_hash_clean
    hash = {:one => 1, :two => nil, :three => '', :four => 'four', :five => {:a => 'apple', :b => nil}, :six => {:c => nil, :d => '', :e => false}}

    assert_equal Hash[:one => 1, :four => 'four', :five => {:a => 'apple'}, :six => {:e => false}], hash.clean

    hash.clean!

    assert_equal Hash[:one => 1, :four => 'four', :five => { :a => 'apple' }, :six => {:e => false}], hash
  end

  def test_mixed_clean
    array = [1,nil, Hash[:two => 2, :three => [3,nil,'', Hash[:four => [4, nil]]]]]
    assert_equal [1,Hash[:two => 2, :three => [3, Hash[:four => [4]]]]], array.clean
  end
end
