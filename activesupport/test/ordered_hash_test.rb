require 'abstract_unit'

class OrderedHashTest < Test::Unit::TestCase
  def setup
    @keys =   %w( blue   green  red    pink   orange )
    @values = %w( 000099 009900 aa0000 cc0066 cc6633 )
    @hash = Hash.new
    @ordered_hash = ActiveSupport::OrderedHash.new

    @keys.each_with_index do |key, index|
      @hash[key] = @values[index]
      @ordered_hash[key] = @values[index]
    end
  end

  def test_order
    assert_equal @keys,   @ordered_hash.keys
    assert_equal @values, @ordered_hash.values
  end

  def test_access
    assert @hash.all? { |k, v| @ordered_hash[k] == v }
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
    assert_equal @ordered_hash.keys.length, @ordered_hash.length

    assert_equal value, @ordered_hash.delete(key)
    assert_equal @keys.length, @ordered_hash.length
    assert_equal @ordered_hash.keys.length, @ordered_hash.length

    assert_nil @ordered_hash.delete(bad_key)
  end

  def test_to_hash
    assert_same @ordered_hash, @ordered_hash.to_hash
  end

  def test_has_key
    assert_equal true, @ordered_hash.has_key?('blue')
    assert_equal true, @ordered_hash.key?('blue')
    assert_equal true, @ordered_hash.include?('blue')
    assert_equal true, @ordered_hash.member?('blue')

    assert_equal false, @ordered_hash.has_key?('indigo')
    assert_equal false, @ordered_hash.key?('indigo')
    assert_equal false, @ordered_hash.include?('indigo')
    assert_equal false, @ordered_hash.member?('indigo')
  end

  def test_has_value
    assert_equal true, @ordered_hash.has_value?('000099')
    assert_equal true, @ordered_hash.value?('000099')
    assert_equal false, @ordered_hash.has_value?('ABCABC')
    assert_equal false, @ordered_hash.value?('ABCABC')
  end

  def test_each_key
    keys = []
    @ordered_hash.each_key { |k| keys << k }
    assert_equal @keys, keys
  end

  def test_each_value
    values = []
    @ordered_hash.each_value { |v| values << v }
    assert_equal @values, values
  end

  def test_each
    values = []
    @ordered_hash.each {|key, value| values << value}
    assert_equal @values, values
  end

  def test_each_with_index
    @ordered_hash.each_with_index { |pair, index| assert_equal [@keys[index], @values[index]], pair}
  end

  def test_each_pair
    values = []
    keys = []
    @ordered_hash.each_pair do |key, value|
      keys << key
      values << value
    end
    assert_equal @values, values
    assert_equal @keys, keys
  end

  def test_delete_if
    copy = @ordered_hash.dup
    copy.delete('pink')
    assert_equal copy, @ordered_hash.delete_if { |k, _| k == 'pink' }
    assert !@ordered_hash.keys.include?('pink')
  end

  def test_reject!
    (copy = @ordered_hash.dup).delete('pink')
    @ordered_hash.reject! { |k, _| k == 'pink' }
    assert_equal copy, @ordered_hash
    assert !@ordered_hash.keys.include?('pink')
  end

  def test_reject
    copy = @ordered_hash.dup
    new_ordered_hash = @ordered_hash.reject { |k, _| k == 'pink' }
    assert_equal copy, @ordered_hash
    assert !new_ordered_hash.keys.include?('pink')
    assert @ordered_hash.keys.include?('pink')
  end

  def test_clear
    @ordered_hash.clear
    assert_equal [], @ordered_hash.keys
  end

  def test_merge
    other_hash =  ActiveSupport::OrderedHash.new
    other_hash['purple'] = '800080'
    other_hash['violet'] = 'ee82ee'
    merged = @ordered_hash.merge other_hash
    assert_equal merged.length, @ordered_hash.length + other_hash.length
    assert_equal @keys + ['purple', 'violet'], merged.keys

    @ordered_hash.merge! other_hash
    assert_equal @ordered_hash, merged
    assert_equal @ordered_hash.keys, merged.keys
  end

  def test_shift
    pair = @ordered_hash.shift
    assert_equal [@keys.first, @values.first], pair
    assert !@ordered_hash.keys.include?(pair.first)
  end
  
  def test_keys
    original = @ordered_hash.keys.dup
    @ordered_hash.keys.pop
    assert_equal original, @ordered_hash.keys
  end

  def test_inspect
    assert @ordered_hash.inspect.include?(@hash.inspect)
  end
end
