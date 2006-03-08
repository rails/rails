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
    assert_equal "", [].to_sentence
    assert_equal "one", ['one'].to_sentence
    assert_equal "one and two", ['one', 'two'].to_sentence
    assert_equal "one, two and three", ['one', 'two', 'three'].to_sentence
    
  end
  
  def test_to_sentence_with_connector
    assert_equal "one, two and also three", ['one', 'two', 'three'].to_sentence(:connector => 'and also')
  end
  
  def test_to_sentence_with_skip_last_comma
    assert_equal "one, two, and three", ['one', 'two', 'three'].to_sentence(:skip_last_comma => false)
  end

  def test_two_elements
    assert_equal "one and two", ['one', 'two'].to_sentence
  end
  
  def test_one_element
    assert_equal "one", ['one'].to_sentence
  end
end

class ArrayExtGroupingTests < Test::Unit::TestCase
  def test_group_by_with_perfect_fit
    groups = []
    ('a'..'i').to_a.in_groups_of(3) do |group|
      groups << group
    end

    assert_equal [%w(a b c), %w(d e f), %w(g h i)], groups
  end

  def test_group_by_with_padding
    groups = []
    ('a'..'g').to_a.in_groups_of(3) do |group|
      groups << group
    end

    assert_equal [%w(a b c), %w(d e f), ['g', nil, nil]], groups
  end

  def test_group_by_pads_with_specified_values
    groups = []

    ('a'..'g').to_a.in_groups_of(3, false) do |group|
      groups << group
    end

    assert_equal [%w(a b c), %w(d e f), ['g', false, false]], groups
  end
end

class ArraToXmlTests < Test::Unit::TestCase
  def test_to_xml
    a = [ { :name => "David", :street_address => "Paulina" }, { :name => "Jason", :street_address => "Evergreen" } ]
    assert_equal(
      "<hashes><hash><street-address type=\"string\">Paulina</street-address><name type=\"string\">David</name></hash><hash><street-address type=\"string\">Evergreen</street-address><name type=\"string\">Jason</name></hash></hashes>",
      a.to_xml
    )
  end
end