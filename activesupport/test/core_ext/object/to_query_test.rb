require 'abstract_unit'
require 'active_support/core_ext/object/to_query'

class ToQueryTest < Test::Unit::TestCase
  def test_simple_conversion
    assert_query_equal 'a=10', :a => 10
  end

  def test_cgi_escaping
    assert_query_equal 'a%3Ab=c+d', 'a:b' => 'c d'
  end

  def test_nil_parameter_value
    empty = Object.new
    def empty.to_param; nil end
    assert_query_equal 'a=', 'a' => empty
  end

  def test_nested_conversion
    assert_query_equal 'person[login]=seckar&person[name]=Nicholas',
      :person => {:name => 'Nicholas', :login => 'seckar'}
  end

  def test_multiple_nested
    assert_query_equal 'account[person][id]=20&person[id]=10',
      :person => {:id => 10}, :account => {:person => {:id => 20}}
  end

  def test_array_values
    assert_query_equal 'person[id][]=10&person[id][]=20',
      :person => {:id => [10, 20]}
  end

  def test_array_values_are_not_sorted
    assert_query_equal 'person[id][]=20&person[id][]=10',
      :person => {:id => [20, 10]}
  end

  private
    def assert_query_equal(expected, actual, message = nil)
      assert_equal expected.split('&'), actual.to_query.split('&')
    end
end
