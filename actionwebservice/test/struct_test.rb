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
  def test_members
    assert_equal(5, StructTest::Struct.members.size)
    assert_equal(Integer, StructTest::Struct.members[:id])
    assert_equal(String, StructTest::Struct.members[:name])
    assert_equal([String], StructTest::Struct.members[:items])
    assert_equal(TrueClass, StructTest::Struct.members[:deleted])
    assert_equal([String], StructTest::Struct.members[:emails])
  end

  def test_initializer_and_lookup
    s = StructTest::Struct.new(:id      => 5,
                               :name    => 'hello',
                               :items   => ['one', 'two'],
                               :deleted => true,
                               :emails  => ['test@test.com'])
    assert_equal(5, s.id)
    assert_equal('hello', s.name)
    assert_equal(['one', 'two'], s.items)
    assert_equal(true, s.deleted)
    assert_equal(['test@test.com'], s.emails)
    assert_equal(5, s['id'])
    assert_equal('hello', s['name'])
    assert_equal(['one', 'two'], s['items'])
    assert_equal(true, s['deleted'])
    assert_equal(['test@test.com'], s['emails'])
  end
end
