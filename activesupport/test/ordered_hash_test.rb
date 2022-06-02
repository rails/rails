# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/json"
require "active_support/core_ext/object/json"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/array/extract_options"

class OrderedHashTest < ActiveSupport::TestCase
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
    key, value = "purple", "5422a8"

    @ordered_hash[key] = value
    assert_equal @keys.length + 1, @ordered_hash.length
    assert_equal key, @ordered_hash.keys.last
    assert_equal value, @ordered_hash.values.last
    assert_equal value, @ordered_hash[key]
  end

  def test_delete
    key, value = "white", "ffffff"
    bad_key = "black"

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
    assert_equal true, @ordered_hash.has_key?("blue")
    assert_equal true, @ordered_hash.key?("blue")
    assert_equal true, @ordered_hash.include?("blue")
    assert_equal true, @ordered_hash.member?("blue")

    assert_equal false, @ordered_hash.has_key?("indigo")
    assert_equal false, @ordered_hash.key?("indigo")
    assert_equal false, @ordered_hash.include?("indigo")
    assert_equal false, @ordered_hash.member?("indigo")
  end

  def test_has_value
    assert_equal true, @ordered_hash.has_value?("000099")
    assert_equal true, @ordered_hash.value?("000099")
    assert_equal false, @ordered_hash.has_value?("ABCABC")
    assert_equal false, @ordered_hash.value?("ABCABC")
  end

  def test_each_key
    keys = []
    assert_equal @ordered_hash, @ordered_hash.each_key { |k| keys << k }
    assert_equal @keys, keys
    assert_kind_of Enumerator, @ordered_hash.each_key
  end

  def test_each_value
    values = []
    assert_equal @ordered_hash, @ordered_hash.each_value { |v| values << v }
    assert_equal @values, values
    assert_kind_of Enumerator, @ordered_hash.each_value
  end

  def test_each
    values = []
    assert_equal @ordered_hash, @ordered_hash.each { |key, value| values << value }
    assert_equal @values, values
    assert_kind_of Enumerator, @ordered_hash.each
  end

  def test_each_with_index
    @ordered_hash.each_with_index { |pair, index| assert_equal [@keys[index], @values[index]], pair }
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
    assert_kind_of Enumerator, @ordered_hash.each_pair
  end

  def test_find_all
    assert_equal @keys, @ordered_hash.find_all { true }.map(&:first)
  end

  def test_select
    new_ordered_hash = @ordered_hash.select { true }
    assert_equal @keys, new_ordered_hash.map(&:first)
    assert_instance_of ActiveSupport::OrderedHash, new_ordered_hash
  end

  def test_delete_if
    copy = @ordered_hash.dup
    copy.delete("pink")
    assert_equal copy, @ordered_hash.delete_if { |k, _| k == "pink" }
    assert_not_includes @ordered_hash.keys, "pink"
  end

  def test_reject!
    (copy = @ordered_hash.dup).delete("pink")
    @ordered_hash.reject! { |k, _| k == "pink" }
    assert_equal copy, @ordered_hash
    assert_not_includes @ordered_hash.keys, "pink"
  end

  def test_reject
    copy = @ordered_hash.dup
    new_ordered_hash = @ordered_hash.reject { |k, _| k == "pink" }
    assert_equal copy, @ordered_hash
    assert_not_includes new_ordered_hash.keys, "pink"
    assert_includes @ordered_hash.keys, "pink"
    assert_instance_of ActiveSupport::OrderedHash, new_ordered_hash
  end

  def test_clear
    @ordered_hash.clear
    assert_equal [], @ordered_hash.keys
  end

  def test_merge
    other_hash = ActiveSupport::OrderedHash.new
    other_hash["purple"] = "800080"
    other_hash["violet"] = "ee82ee"
    merged = @ordered_hash.merge other_hash
    assert_equal merged.length, @ordered_hash.length + other_hash.length
    assert_equal @keys + ["purple", "violet"], merged.keys
  end

  def test_merge_with_block
    hash = ActiveSupport::OrderedHash.new
    hash[:a] = 0
    hash[:b] = 0
    merged = hash.merge(b: 2, c: 7) do |key, old_value, new_value|
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
    hash.merge!(a: 1, c: 7) do |key, old_value, new_value|
      new_value + 3
    end

    assert_equal 4, hash[:a]
    assert_equal 0, hash[:b]
    assert_equal 7, hash[:c]
  end

  def test_shift
    pair = @ordered_hash.shift
    assert_equal [@keys.first, @values.first], pair
    assert_not_includes @ordered_hash.keys, pair.first
  end

  def test_keys
    original = @ordered_hash.keys.dup
    @ordered_hash.keys.pop
    assert_equal original, @ordered_hash.keys
  end

  def test_inspect
    assert_includes @ordered_hash.inspect, @hash.inspect
  end

  def test_json
    ordered_hash = ActiveSupport::OrderedHash[:foo, :bar]
    hash = Hash[:foo, :bar]
    assert_equal ordered_hash.to_json, hash.to_json
  end

  def test_alternate_initialization_with_splat
    alternate = ActiveSupport::OrderedHash[1, 2, 3, 4]
    assert_kind_of ActiveSupport::OrderedHash, alternate
    assert_equal [1, 3], alternate.keys
  end

  def test_alternate_initialization_with_array
    alternate = ActiveSupport::OrderedHash[ [
      [1, 2],
      [3, 4],
      [ "missing value" ]
    ]]

    assert_kind_of ActiveSupport::OrderedHash, alternate
    assert_equal [1, 3, "missing value"], alternate.keys
    assert_equal [2, 4, nil ], alternate.values
  end

  def test_alternate_initialization_raises_exception_on_odd_length_args
    assert_raises ArgumentError do
      ActiveSupport::OrderedHash[1, 2, 3, 4, 5]
    end
  end

  def test_replace_updates_keys
    @other_ordered_hash = ActiveSupport::OrderedHash[:black, "000000", :white, "000000"]
    original = @ordered_hash.replace(@other_ordered_hash)
    assert_same original, @ordered_hash
    assert_equal @other_ordered_hash.keys, @ordered_hash.keys
  end

  def test_nested_under_indifferent_access
    flash = { a: ActiveSupport::OrderedHash[:b, 1, :c, 2] }.with_indifferent_access
    assert_kind_of ActiveSupport::OrderedHash, flash[:a]
  end

  def test_each_after_yaml_serialization
    assert_equal @values, YAML.load(YAML.dump(@ordered_hash)).values
  end

  def test_each_when_yielding_to_block_with_splat
    hash_values         = []
    ordered_hash_values = []

    @hash.each         { |*v| hash_values         << v }
    @ordered_hash.each { |*v| ordered_hash_values << v }

    assert_equal hash_values.sort, ordered_hash_values.sort
  end

  def test_each_pair_when_yielding_to_block_with_splat
    hash_values         = []
    ordered_hash_values = []

    @hash.each_pair         { |*v| hash_values         << v }
    @ordered_hash.each_pair { |*v| ordered_hash_values << v }

    assert_equal hash_values.sort, ordered_hash_values.sort
  end

  def test_order_after_yaml_serialization
    @deserialized_ordered_hash = YAML.load(YAML.dump(@ordered_hash))

    assert_equal @keys,   @deserialized_ordered_hash.keys
    assert_equal @values, @deserialized_ordered_hash.values
  end

  def test_order_after_yaml_serialization_with_nested_arrays
    @ordered_hash[:array] = %w(a b c)

    @deserialized_ordered_hash = YAML.load(YAML.dump(@ordered_hash))

    assert_equal @ordered_hash.keys,   @deserialized_ordered_hash.keys
    assert_equal @ordered_hash.values, @deserialized_ordered_hash.values
  end

  def test_psych_serialize
    @deserialized_ordered_hash = Psych.load(Psych.dump(@ordered_hash))

    values = @deserialized_ordered_hash.map { |_, value| value }
    assert_equal @values, values
  end

  def test_psych_serialize_tag
    yaml = Psych.dump(@ordered_hash)
    assert_match "!omap", yaml
  end

  def test_has_yaml_tag
    @ordered_hash[:array] = %w(a b c)
    assert_match "!omap", YAML.dump(@ordered_hash)
  end

  def test_update_sets_keys
    @updated_ordered_hash = ActiveSupport::OrderedHash.new
    @updated_ordered_hash.update(name: "Bob")
    assert_equal [:name],  @updated_ordered_hash.keys
  end

  def test_invert
    expected = ActiveSupport::OrderedHash[@values.zip(@keys)]
    assert_equal expected, @ordered_hash.invert
    assert_equal @values.zip(@keys), @ordered_hash.invert.to_a
  end

  def test_extractable
    @ordered_hash[:rails] = "snowman"
    assert_equal @ordered_hash, [1, 2, @ordered_hash].extract_options!
  end
end
