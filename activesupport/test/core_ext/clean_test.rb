# encoding: utf-8

require 'abstract_unit'
require 'active_support/core_ext/enumerable'

class CleanTest < ActiveSupport::TestCase
  def test_array_clean
    array = [1,nil,2,['',3,nil,[4,[5]]]]
    clean = [1,2,[3,[4,[5]]]]

    assert_equal clean, array.clean
    assert_equal [1,nil,2,['',3,nil,[4,[5]]]], array # unmodified

    array.clean!
    assert_equal clean, array # modified
  end

  def test_hash_clean
    hash  = {:one => 1, :two => nil, :three => 'three', :four => {:a => 5..10, :b => ''}}
    clean = {:one => 1, :three => 'three', :four => {:a => 5..10}}

    assert_equal clean, hash.clean
    assert_equal Hash[:one => 1, :two => nil, :three => 'three', :four => {:a => 5..10, :b => ''}], hash # unmodified

    hash.clean!
    assert_equal clean, hash # modified
  end

  def test_mixed_clean
    array = [1, nil, Hash[:two => 2, :three => [3,nil,'', Hash[:four => [4, nil]]]]]
    clean = [1, Hash[:two => 2, :three => [3, Hash[:four => [4]]]]]

    assert_equal clean, array.clean
    assert_equal clean, array.clean!
  end
end
