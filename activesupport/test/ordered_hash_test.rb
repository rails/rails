require 'abstract_unit'

class OrderedHashTest < Test::Unit::TestCase
  def setup
    @keys =   %w( blue   green  red    pink   orange )
    @values = %w( 000099 009900 aa0000 cc0066 cc6633 )
    @ordered_hash = ActiveSupport::OrderedHash.new

    @keys.each_with_index do |key, index|
      @ordered_hash[key] = @values[index]
    end
  end

  def test_order
    assert_equal @keys,   @ordered_hash.keys
    assert_equal @values, @ordered_hash.values
  end

  def test_access
    assert @keys.zip(@values).all? { |k, v| @ordered_hash[k] == v }
  end

  def test_assignment
    key, value = 'purple', '5422a8'

    @ordered_hash[key] = value
    assert_equal @keys.length + 1, @ordered_hash.length
    assert_equal key, @ordered_hash.keys.last
    assert_equal value, @ordered_hash.values.last
    assert_equal value, @ordered_hash[key]
  end

  def test_delete
    key, value = 'white', 'ffffff'
    bad_key = 'black'

    @ordered_hash[key] = value
    assert_equal @keys.length + 1, @ordered_hash.length

    assert_equal value, @ordered_hash.delete(key)
    assert_equal @keys.length, @ordered_hash.length

    assert_nil @ordered_hash.delete(bad_key)
  end
end
