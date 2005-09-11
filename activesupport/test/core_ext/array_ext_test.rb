require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/array'

class ArrayExtToParamTests < Test::Unit::TestCase
  def test_string_array
    assert_equal '', %w().to_param
    assert_equal 'hello/world', %w(hello world).to_param
    assert_equal 'hello/10', %w(hello 10).to_param
  end
  
  def test_number_array
    assert_equal '10/20', [10, 20].to_param
  end
end

class ArrayExtConversionTests < Test::Unit::TestCase
  def test_plain_array_to_sentence
    assert_equal "one, two, and three", ['one', 'two', 'three'].to_sentence
  end
  
  def test_to_sentence_with_connector
    assert_equal "one, two, and also three", ['one', 'two', 'three'].to_sentence(:connector => 'and also')
  end
  
  def test_to_sentence_with_skip_last_comma
    assert_equal "one, two and three", ['one', 'two', 'three'].to_sentence(:skip_last_comma => true)
  end

  def test_two_elements
    assert_equal "one and two", ['one', 'two'].to_sentence
  end
  
  def test_one_element
    assert_equal "one", ['one'].to_sentence
  end
end
