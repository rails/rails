require File.dirname(__FILE__) + '/abstract_unit'

module StructTest
  class Struct < ActionWebService::Struct
    member :id, Integer
    member :name, String
    member :items, [String]
    member :deleted, :bool
    member :emails, [:string]
  end
end

class TC_Struct < Test::Unit::TestCase
  include StructTest

  def setup
    @struct = Struct.new(:id      => 5,
                         :name    => 'hello',
                         :items   => ['one', 'two'],
                         :deleted => true,
                         :emails  => ['test@test.com'])
  end

  def test_members
    assert_equal(5, Struct.members.size)
    assert_equal(Integer, Struct.members[:id].type_class)
    assert_equal(String, Struct.members[:name].type_class)
    assert_equal(String, Struct.members[:items].element_type.type_class)
    assert_equal(TrueClass, Struct.members[:deleted].type_class)
    assert_equal(String, Struct.members[:emails].element_type.type_class)
  end

  def test_initializer_and_lookup
    assert_equal(5, @struct.id)
    assert_equal('hello', @struct.name)
    assert_equal(['one', 'two'], @struct.items)
    assert_equal(true, @struct.deleted)
    assert_equal(['test@test.com'], @struct.emails)
    assert_equal(5, @struct['id'])
    assert_equal('hello', @struct['name'])
    assert_equal(['one', 'two'], @struct['items'])
    assert_equal(true, @struct['deleted'])
    assert_equal(['test@test.com'], @struct['emails'])
  end

  def test_each_pair
    @struct.each_pair do |name, value|
      assert_equal @struct.__send__(name), value
      assert_equal @struct[name], value
    end
  end
end
