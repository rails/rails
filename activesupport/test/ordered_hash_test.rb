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

  def test_to_a
    assert_equal @keys.zip(@values), @ordered_hash.to_a
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

  def test_merge_with_block
    hash = ActiveSupport::OrderedHash.new
    hash[:a] = 0
    hash[:b] = 0
    merged = hash.merge(:b => 2, :c => 7) do |key, old_value, new_value|
      new_value + 1
    end

    assert_equal 0, merged[:a]
    assert_equal 3, merged[:b]
    assert_equal 7, merged[:c]
  end

  def test_merge_bang_with_block
    hash = ActiveSupport::OrderedHash.new
    hash[:a] = 0
    hash[:b] = 0
    hash.merge!(:a => 1, :c => 7) do |key, old_value, new_value|
      new_value + 3
    end

    assert_equal 4, hash[:a]
    assert_equal 0, hash[:b]
    assert_equal 7, hash[:c]
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

  def test_alternate_initialization_with_splat
    alternate = ActiveSupport::OrderedHash[1,2,3,4]
    assert_kind_of ActiveSupport::OrderedHash, alternate
    assert_equal [1, 3], alternate.keys
  end

  def test_alternate_initialization_with_array
    alternate = ActiveSupport::OrderedHash[ [
      [1, 2],
      [3, 4],
      "bad key value pair",
      [ 'missing value' ]
    ]]

    assert_kind_of ActiveSupport::OrderedHash, alternate
    assert_equal [1, 3, 'missing value'], alternate.keys
    assert_equal [2, 4, nil ], alternate.values
  end

  def test_alternate_initialization_raises_exception_on_odd_length_args
    begin
      alternate = ActiveSupport::OrderedHash[1,2,3,4,5]
      flunk "Hash::[] should have raised an exception on initialization " +
          "with an odd number of parameters"
    rescue
      assert_equal "odd number of arguments for Hash", $!.message
    end
  end

  def test_replace_updates_keys
    @other_ordered_hash = ActiveSupport::OrderedHash[:black, '000000', :white, '000000']
    original = @ordered_hash.replace(@other_ordered_hash)
    assert_same original, @ordered_hash
    assert_equal @other_ordered_hash.keys, @ordered_hash.keys
  end

  def test_each_after_yaml_serialization
    values = []
    @deserialized_ordered_hash = YAML::load(YAML::dump(@ordered_hash))

    @deserialized_ordered_hash.each {|key, value| values << value}
    assert_equal @values, values
  end

  def test_order_after_yaml_serialization
    @deserialized_ordered_hash = YAML::load(YAML::dump(@ordered_hash))

    assert_equal @keys,   @deserialized_ordered_hash.keys
    assert_equal @values, @deserialized_ordered_hash.values
  end

  def test_order_after_yaml_serialization_with_nested_arrays
    @ordered_hash[:array] = %w(a b c)

    @deserialized_ordered_hash = YAML::load(YAML::dump(@ordered_hash))

    assert_equal @ordered_hash.keys,   @deserialized_ordered_hash.keys
    assert_equal @ordered_hash.values, @deserialized_ordered_hash.values
  end

  def test_update_sets_keys
    @updated_ordered_hash = ActiveSupport::OrderedHash.new
    @updated_ordered_hash.update(:name => "Bob")
    assert_equal [:name],  @updated_ordered_hash.keys
  end

  def test_invert
    expected = ActiveSupport::OrderedHash[@values.zip(@keys)]
    assert_equal expected, @ordered_hash.invert
    assert_equal @values.zip(@keys), @ordered_hash.invert.to_a
  end
end
