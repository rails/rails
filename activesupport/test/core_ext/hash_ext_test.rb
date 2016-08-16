require "abstract_unit"
require "active_support/core_ext/hash"
require "bigdecimal"
require "active_support/core_ext/string/access"
require "active_support/ordered_hash"
require "active_support/core_ext/object/conversions"
require "active_support/core_ext/object/deep_dup"
require "active_support/inflections"

class HashExtTest < ActiveSupport::TestCase
  class IndifferentHash < ActiveSupport::HashWithIndifferentAccess
  end

  class SubclassingArray < Array
  end

  class SubclassingHash < Hash
  end

  class NonIndifferentHash < Hash
    def nested_under_indifferent_access
      self
    end
  end

  class HashByConversion
    def initialize(hash)
      @hash = hash
    end

    def to_hash
      @hash
    end
  end

  def setup
    @strings = { "a" => 1, "b" => 2 }
    @nested_strings = { "a" => { "b" => { "c" => 3 } } }
    @symbols = { a: 1, b: 2 }
    @nested_symbols = { a: { b: { c: 3 } } }
    @mixed = { :a => 1, "b" => 2 }
    @nested_mixed = { "a" => { b: { "c" => 3 } } }
    @integers = { 0 => 1, 1 => 2 }
    @nested_integers = { 0 => { 1 => { 2 => 3 } } }
    @illegal_symbols = { [] => 3 }
    @nested_illegal_symbols = { [] => { [] => 3 } }
    @upcase_strings = { "A" => 1, "B" => 2 }
    @nested_upcase_strings = { "A" => { "B" => { "C" => 3 } } }
    @string_array_of_hashes = { "a" => [ { "b" => 2 }, { "c" => 3 }, 4 ] }
    @symbol_array_of_hashes = { a: [ { b: 2 }, { c: 3 }, 4 ] }
    @mixed_array_of_hashes = { a: [ { b: 2 }, { "c" => 3 }, 4 ] }
    @upcase_array_of_hashes = { "A" => [ { "B" => 2 }, { "C" => 3 }, 4 ] }
  end

  def test_methods
    h = {}
    assert_respond_to h, :transform_keys
    assert_respond_to h, :transform_keys!
    assert_respond_to h, :deep_transform_keys
    assert_respond_to h, :deep_transform_keys!
    assert_respond_to h, :symbolize_keys
    assert_respond_to h, :symbolize_keys!
    assert_respond_to h, :deep_symbolize_keys
    assert_respond_to h, :deep_symbolize_keys!
    assert_respond_to h, :stringify_keys
    assert_respond_to h, :stringify_keys!
    assert_respond_to h, :deep_stringify_keys
    assert_respond_to h, :deep_stringify_keys!
    assert_respond_to h, :to_options
    assert_respond_to h, :to_options!
    assert_respond_to h, :compact
    assert_respond_to h, :compact!
    assert_respond_to h, :except
    assert_respond_to h, :except!
  end

  def test_transform_keys
    assert_equal @upcase_strings, @strings.transform_keys { |key| key.to_s.upcase }
    assert_equal @upcase_strings, @symbols.transform_keys { |key| key.to_s.upcase }
    assert_equal @upcase_strings, @mixed.transform_keys { |key| key.to_s.upcase }
  end

  def test_transform_keys_not_mutates
    transformed_hash = @mixed.dup
    transformed_hash.transform_keys { |key| key.to_s.upcase }
    assert_equal @mixed, transformed_hash
  end

  def test_deep_transform_keys
    assert_equal @nested_upcase_strings, @nested_symbols.deep_transform_keys { |key| key.to_s.upcase }
    assert_equal @nested_upcase_strings, @nested_strings.deep_transform_keys { |key| key.to_s.upcase }
    assert_equal @nested_upcase_strings, @nested_mixed.deep_transform_keys { |key| key.to_s.upcase }
    assert_equal @upcase_array_of_hashes, @string_array_of_hashes.deep_transform_keys { |key| key.to_s.upcase }
    assert_equal @upcase_array_of_hashes, @symbol_array_of_hashes.deep_transform_keys { |key| key.to_s.upcase }
    assert_equal @upcase_array_of_hashes, @mixed_array_of_hashes.deep_transform_keys { |key| key.to_s.upcase }
  end

  def test_deep_transform_keys_not_mutates
    transformed_hash = @nested_mixed.deep_dup
    transformed_hash.deep_transform_keys { |key| key.to_s.upcase }
    assert_equal @nested_mixed, transformed_hash
  end

  def test_transform_keys!
    assert_equal @upcase_strings, @symbols.dup.transform_keys! { |key| key.to_s.upcase }
    assert_equal @upcase_strings, @strings.dup.transform_keys! { |key| key.to_s.upcase }
    assert_equal @upcase_strings, @mixed.dup.transform_keys! { |key| key.to_s.upcase }
  end

  def test_transform_keys_with_bang_mutates
    transformed_hash = @mixed.dup
    transformed_hash.transform_keys! { |key| key.to_s.upcase }
    assert_equal @upcase_strings, transformed_hash
    assert_equal @mixed, :a => 1, "b" => 2
  end

  def test_deep_transform_keys!
    assert_equal @nested_upcase_strings, @nested_symbols.deep_dup.deep_transform_keys! { |key| key.to_s.upcase }
    assert_equal @nested_upcase_strings, @nested_strings.deep_dup.deep_transform_keys! { |key| key.to_s.upcase }
    assert_equal @nested_upcase_strings, @nested_mixed.deep_dup.deep_transform_keys! { |key| key.to_s.upcase }
    assert_equal @upcase_array_of_hashes, @string_array_of_hashes.deep_dup.deep_transform_keys! { |key| key.to_s.upcase }
    assert_equal @upcase_array_of_hashes, @symbol_array_of_hashes.deep_dup.deep_transform_keys! { |key| key.to_s.upcase }
    assert_equal @upcase_array_of_hashes, @mixed_array_of_hashes.deep_dup.deep_transform_keys! { |key| key.to_s.upcase }
  end

  def test_deep_transform_keys_with_bang_mutates
    transformed_hash = @nested_mixed.deep_dup
    transformed_hash.deep_transform_keys! { |key| key.to_s.upcase }
    assert_equal @nested_upcase_strings, transformed_hash
    assert_equal @nested_mixed, "a" => { b: { "c" => 3 } }
  end

  def test_symbolize_keys
    assert_equal @symbols, @symbols.symbolize_keys
    assert_equal @symbols, @strings.symbolize_keys
    assert_equal @symbols, @mixed.symbolize_keys
  end

  def test_symbolize_keys_not_mutates
    transformed_hash = @mixed.dup
    transformed_hash.symbolize_keys
    assert_equal @mixed, transformed_hash
  end

  def test_deep_symbolize_keys
    assert_equal @nested_symbols, @nested_symbols.deep_symbolize_keys
    assert_equal @nested_symbols, @nested_strings.deep_symbolize_keys
    assert_equal @nested_symbols, @nested_mixed.deep_symbolize_keys
    assert_equal @symbol_array_of_hashes, @string_array_of_hashes.deep_symbolize_keys
    assert_equal @symbol_array_of_hashes, @symbol_array_of_hashes.deep_symbolize_keys
    assert_equal @symbol_array_of_hashes, @mixed_array_of_hashes.deep_symbolize_keys
  end

  def test_deep_symbolize_keys_not_mutates
    transformed_hash = @nested_mixed.deep_dup
    transformed_hash.deep_symbolize_keys
    assert_equal @nested_mixed, transformed_hash
  end

  def test_symbolize_keys!
    assert_equal @symbols, @symbols.dup.symbolize_keys!
    assert_equal @symbols, @strings.dup.symbolize_keys!
    assert_equal @symbols, @mixed.dup.symbolize_keys!
  end

  def test_symbolize_keys_with_bang_mutates
    transformed_hash = @mixed.dup
    transformed_hash.deep_symbolize_keys!
    assert_equal @symbols, transformed_hash
    assert_equal @mixed, :a => 1, "b" => 2
  end

  def test_deep_symbolize_keys!
    assert_equal @nested_symbols, @nested_symbols.deep_dup.deep_symbolize_keys!
    assert_equal @nested_symbols, @nested_strings.deep_dup.deep_symbolize_keys!
    assert_equal @nested_symbols, @nested_mixed.deep_dup.deep_symbolize_keys!
    assert_equal @symbol_array_of_hashes, @string_array_of_hashes.deep_dup.deep_symbolize_keys!
    assert_equal @symbol_array_of_hashes, @symbol_array_of_hashes.deep_dup.deep_symbolize_keys!
    assert_equal @symbol_array_of_hashes, @mixed_array_of_hashes.deep_dup.deep_symbolize_keys!
  end

  def test_deep_symbolize_keys_with_bang_mutates
    transformed_hash = @nested_mixed.deep_dup
    transformed_hash.deep_symbolize_keys!
    assert_equal @nested_symbols, transformed_hash
    assert_equal @nested_mixed, "a" => { b: { "c" => 3 } }
  end

  def test_symbolize_keys_preserves_keys_that_cant_be_symbolized
    assert_equal @illegal_symbols, @illegal_symbols.symbolize_keys
    assert_equal @illegal_symbols, @illegal_symbols.dup.symbolize_keys!
  end

  def test_deep_symbolize_keys_preserves_keys_that_cant_be_symbolized
    assert_equal @nested_illegal_symbols, @nested_illegal_symbols.deep_symbolize_keys
    assert_equal @nested_illegal_symbols, @nested_illegal_symbols.deep_dup.deep_symbolize_keys!
  end

  def test_symbolize_keys_preserves_integer_keys
    assert_equal @integers, @integers.symbolize_keys
    assert_equal @integers, @integers.dup.symbolize_keys!
  end

  def test_deep_symbolize_keys_preserves_integer_keys
    assert_equal @nested_integers, @nested_integers.deep_symbolize_keys
    assert_equal @nested_integers, @nested_integers.deep_dup.deep_symbolize_keys!
  end

  def test_stringify_keys
    assert_equal @strings, @symbols.stringify_keys
    assert_equal @strings, @strings.stringify_keys
    assert_equal @strings, @mixed.stringify_keys
  end

  def test_stringify_keys_not_mutates
    transformed_hash = @mixed.dup
    transformed_hash.stringify_keys
    assert_equal @mixed, transformed_hash
  end

  def test_deep_stringify_keys
    assert_equal @nested_strings, @nested_symbols.deep_stringify_keys
    assert_equal @nested_strings, @nested_strings.deep_stringify_keys
    assert_equal @nested_strings, @nested_mixed.deep_stringify_keys
    assert_equal @string_array_of_hashes, @string_array_of_hashes.deep_stringify_keys
    assert_equal @string_array_of_hashes, @symbol_array_of_hashes.deep_stringify_keys
    assert_equal @string_array_of_hashes, @mixed_array_of_hashes.deep_stringify_keys
  end

  def test_deep_stringify_keys_not_mutates
    transformed_hash = @nested_mixed.deep_dup
    transformed_hash.deep_stringify_keys
    assert_equal @nested_mixed, transformed_hash
  end

  def test_stringify_keys!
    assert_equal @strings, @symbols.dup.stringify_keys!
    assert_equal @strings, @strings.dup.stringify_keys!
    assert_equal @strings, @mixed.dup.stringify_keys!
  end

  def test_stringify_keys_with_bang_mutates
    transformed_hash = @mixed.dup
    transformed_hash.stringify_keys!
    assert_equal @strings, transformed_hash
    assert_equal @mixed, :a => 1, "b" => 2
  end

  def test_deep_stringify_keys!
    assert_equal @nested_strings, @nested_symbols.deep_dup.deep_stringify_keys!
    assert_equal @nested_strings, @nested_strings.deep_dup.deep_stringify_keys!
    assert_equal @nested_strings, @nested_mixed.deep_dup.deep_stringify_keys!
    assert_equal @string_array_of_hashes, @string_array_of_hashes.deep_dup.deep_stringify_keys!
    assert_equal @string_array_of_hashes, @symbol_array_of_hashes.deep_dup.deep_stringify_keys!
    assert_equal @string_array_of_hashes, @mixed_array_of_hashes.deep_dup.deep_stringify_keys!
  end

  def test_deep_stringify_keys_with_bang_mutates
    transformed_hash = @nested_mixed.deep_dup
    transformed_hash.deep_stringify_keys!
    assert_equal @nested_strings, transformed_hash
    assert_equal @nested_mixed, "a" => { b: { "c" => 3 } }
  end

  def test_symbolize_keys_for_hash_with_indifferent_access
    assert_instance_of Hash, @symbols.with_indifferent_access.symbolize_keys
    assert_equal @symbols, @symbols.with_indifferent_access.symbolize_keys
    assert_equal @symbols, @strings.with_indifferent_access.symbolize_keys
    assert_equal @symbols, @mixed.with_indifferent_access.symbolize_keys
  end

  def test_deep_symbolize_keys_for_hash_with_indifferent_access
    assert_instance_of Hash, @nested_symbols.with_indifferent_access.deep_symbolize_keys
    assert_equal @nested_symbols, @nested_symbols.with_indifferent_access.deep_symbolize_keys
    assert_equal @nested_symbols, @nested_strings.with_indifferent_access.deep_symbolize_keys
    assert_equal @nested_symbols, @nested_mixed.with_indifferent_access.deep_symbolize_keys
  end

  def test_symbolize_keys_bang_for_hash_with_indifferent_access
    assert_raise(NoMethodError) { @symbols.with_indifferent_access.dup.symbolize_keys! }
    assert_raise(NoMethodError) { @strings.with_indifferent_access.dup.symbolize_keys! }
    assert_raise(NoMethodError) { @mixed.with_indifferent_access.dup.symbolize_keys! }
  end

  def test_deep_symbolize_keys_bang_for_hash_with_indifferent_access
    assert_raise(NoMethodError) { @nested_symbols.with_indifferent_access.deep_dup.deep_symbolize_keys! }
    assert_raise(NoMethodError) { @nested_strings.with_indifferent_access.deep_dup.deep_symbolize_keys! }
    assert_raise(NoMethodError) { @nested_mixed.with_indifferent_access.deep_dup.deep_symbolize_keys! }
  end

  def test_symbolize_keys_preserves_keys_that_cant_be_symbolized_for_hash_with_indifferent_access
    assert_equal @illegal_symbols, @illegal_symbols.with_indifferent_access.symbolize_keys
    assert_raise(NoMethodError) { @illegal_symbols.with_indifferent_access.dup.symbolize_keys! }
  end

  def test_deep_symbolize_keys_preserves_keys_that_cant_be_symbolized_for_hash_with_indifferent_access
    assert_equal @nested_illegal_symbols, @nested_illegal_symbols.with_indifferent_access.deep_symbolize_keys
    assert_raise(NoMethodError) { @nested_illegal_symbols.with_indifferent_access.deep_dup.deep_symbolize_keys! }
  end

  def test_symbolize_keys_preserves_integer_keys_for_hash_with_indifferent_access
    assert_equal @integers, @integers.with_indifferent_access.symbolize_keys
    assert_raise(NoMethodError) { @integers.with_indifferent_access.dup.symbolize_keys! }
  end

  def test_deep_symbolize_keys_preserves_integer_keys_for_hash_with_indifferent_access
    assert_equal @nested_integers, @nested_integers.with_indifferent_access.deep_symbolize_keys
    assert_raise(NoMethodError) { @nested_integers.with_indifferent_access.deep_dup.deep_symbolize_keys! }
  end

  def test_stringify_keys_for_hash_with_indifferent_access
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, @symbols.with_indifferent_access.stringify_keys
    assert_equal @strings, @symbols.with_indifferent_access.stringify_keys
    assert_equal @strings, @strings.with_indifferent_access.stringify_keys
    assert_equal @strings, @mixed.with_indifferent_access.stringify_keys
  end

  def test_deep_stringify_keys_for_hash_with_indifferent_access
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, @nested_symbols.with_indifferent_access.deep_stringify_keys
    assert_equal @nested_strings, @nested_symbols.with_indifferent_access.deep_stringify_keys
    assert_equal @nested_strings, @nested_strings.with_indifferent_access.deep_stringify_keys
    assert_equal @nested_strings, @nested_mixed.with_indifferent_access.deep_stringify_keys
  end

  def test_stringify_keys_bang_for_hash_with_indifferent_access
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, @symbols.with_indifferent_access.dup.stringify_keys!
    assert_equal @strings, @symbols.with_indifferent_access.dup.stringify_keys!
    assert_equal @strings, @strings.with_indifferent_access.dup.stringify_keys!
    assert_equal @strings, @mixed.with_indifferent_access.dup.stringify_keys!
  end

  def test_deep_stringify_keys_bang_for_hash_with_indifferent_access
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, @nested_symbols.with_indifferent_access.dup.deep_stringify_keys!
    assert_equal @nested_strings, @nested_symbols.with_indifferent_access.deep_dup.deep_stringify_keys!
    assert_equal @nested_strings, @nested_strings.with_indifferent_access.deep_dup.deep_stringify_keys!
    assert_equal @nested_strings, @nested_mixed.with_indifferent_access.deep_dup.deep_stringify_keys!
  end

  def test_nested_under_indifferent_access
    foo = { "foo" => SubclassingHash.new.tap { |h| h["bar"] = "baz" } }.with_indifferent_access
    assert_kind_of ActiveSupport::HashWithIndifferentAccess, foo["foo"]

    foo = { "foo" => NonIndifferentHash.new.tap { |h| h["bar"] = "baz" } }.with_indifferent_access
    assert_kind_of NonIndifferentHash, foo["foo"]

    foo = { "foo" => IndifferentHash.new.tap { |h| h["bar"] = "baz" } }.with_indifferent_access
    assert_kind_of IndifferentHash, foo["foo"]
  end

  def test_indifferent_assorted
    @strings = @strings.with_indifferent_access
    @symbols = @symbols.with_indifferent_access
    @mixed   = @mixed.with_indifferent_access

    assert_equal "a", @strings.__send__(:convert_key, :a)

    assert_equal 1, @strings.fetch("a")
    assert_equal 1, @strings.fetch(:a.to_s)
    assert_equal 1, @strings.fetch(:a)

    hashes = { :@strings => @strings, :@symbols => @symbols, :@mixed => @mixed }
    method_map = { '[]': 1, fetch: 1, values_at: [1],
      has_key?: true, include?: true, key?: true,
      member?: true }

    hashes.each do |name, hash|
      method_map.sort_by(&:to_s).each do |meth, expected|
        assert_equal(expected, hash.__send__(meth, "a"),
                     "Calling #{name}.#{meth} 'a'")
        assert_equal(expected, hash.__send__(meth, :a),
                     "Calling #{name}.#{meth} :a")
      end
    end

    assert_equal [1, 2], @strings.values_at("a", "b")
    assert_equal [1, 2], @strings.values_at(:a, :b)
    assert_equal [1, 2], @symbols.values_at("a", "b")
    assert_equal [1, 2], @symbols.values_at(:a, :b)
    assert_equal [1, 2], @mixed.values_at("a", "b")
    assert_equal [1, 2], @mixed.values_at(:a, :b)
  end

  def test_indifferent_reading
    hash = HashWithIndifferentAccess.new
    hash["a"] = 1
    hash["b"] = true
    hash["c"] = false
    hash["d"] = nil

    assert_equal 1, hash[:a]
    assert_equal true, hash[:b]
    assert_equal false, hash[:c]
    assert_equal nil, hash[:d]
    assert_equal nil, hash[:e]
  end

  def test_indifferent_reading_with_nonnil_default
    hash = HashWithIndifferentAccess.new(1)
    hash["a"] = 1
    hash["b"] = true
    hash["c"] = false
    hash["d"] = nil

    assert_equal 1, hash[:a]
    assert_equal true, hash[:b]
    assert_equal false, hash[:c]
    assert_equal nil, hash[:d]
    assert_equal 1, hash[:e]
  end

  def test_indifferent_writing
    hash = HashWithIndifferentAccess.new
    hash[:a] = 1
    hash["b"] = 2
    hash[3] = 3

    assert_equal hash["a"], 1
    assert_equal hash["b"], 2
    assert_equal hash[:a], 1
    assert_equal hash[:b], 2
    assert_equal hash[3], 3
  end

  def test_indifferent_update
    hash = HashWithIndifferentAccess.new
    hash[:a] = "a"
    hash["b"] = "b"

    updated_with_strings = hash.update(@strings)
    updated_with_symbols = hash.update(@symbols)
    updated_with_mixed = hash.update(@mixed)

    assert_equal updated_with_strings[:a], 1
    assert_equal updated_with_strings["a"], 1
    assert_equal updated_with_strings["b"], 2

    assert_equal updated_with_symbols[:a], 1
    assert_equal updated_with_symbols["b"], 2
    assert_equal updated_with_symbols[:b], 2

    assert_equal updated_with_mixed[:a], 1
    assert_equal updated_with_mixed["b"], 2

    assert [updated_with_strings, updated_with_symbols, updated_with_mixed].all? { |h| h.keys.size == 2 }
  end

  def test_update_with_to_hash_conversion
    hash = HashWithIndifferentAccess.new
    hash.update HashByConversion.new(a: 1)
    assert_equal hash["a"], 1
  end

  def test_indifferent_merging
    hash = HashWithIndifferentAccess.new
    hash[:a] = "failure"
    hash["b"] = "failure"

    other = { "a" => 1, :b => 2 }

    merged = hash.merge(other)

    assert_equal HashWithIndifferentAccess, merged.class
    assert_equal 1, merged[:a]
    assert_equal 2, merged["b"]

    hash.update(other)

    assert_equal 1, hash[:a]
    assert_equal 2, hash["b"]
  end

  def test_merge_with_to_hash_conversion
    hash = HashWithIndifferentAccess.new
    merged = hash.merge HashByConversion.new(a: 1)
    assert_equal merged["a"], 1
  end

  def test_indifferent_replace
    hash = HashWithIndifferentAccess.new
    hash[:a] = 42

    replaced = hash.replace(b: 12)

    assert hash.key?("b")
    assert !hash.key?(:a)
    assert_equal 12, hash[:b]
    assert_same hash, replaced
  end

  def test_replace_with_to_hash_conversion
    hash = HashWithIndifferentAccess.new
    hash[:a] = 42

    replaced = hash.replace(HashByConversion.new(b: 12))

    assert hash.key?("b")
    assert !hash.key?(:a)
    assert_equal 12, hash[:b]
    assert_same hash, replaced
  end

  def test_indifferent_merging_with_block
    hash = HashWithIndifferentAccess.new
    hash[:a] = 1
    hash["b"] = 3

    other = { "a" => 4, :b => 2, "c" => 10 }

    merged = hash.merge(other) { |key, old, new| old > new ? old : new }

    assert_equal HashWithIndifferentAccess, merged.class
    assert_equal 4, merged[:a]
    assert_equal 3, merged["b"]
    assert_equal 10, merged[:c]

    other_indifferent = HashWithIndifferentAccess.new("a" => 9, :b => 2)

    merged = hash.merge(other_indifferent) { |key, old, new| old + new }

    assert_equal HashWithIndifferentAccess, merged.class
    assert_equal 10, merged[:a]
    assert_equal 5, merged[:b]
  end

  def test_indifferent_reverse_merging
    hash = HashWithIndifferentAccess.new key: :old_value
    hash.reverse_merge! key: :new_value
    assert_equal :old_value, hash[:key]

    hash = HashWithIndifferentAccess.new("some" => "value", "other" => "value")
    hash.reverse_merge!(some: "noclobber", another: "clobber")
    assert_equal "value", hash[:some]
    assert_equal "clobber", hash[:another]
  end

  def test_indifferent_deleting
    get_hash = proc { { a: "foo" }.with_indifferent_access }
    hash = get_hash.call
    assert_equal hash.delete(:a), "foo"
    assert_equal hash.delete(:a), nil
    hash = get_hash.call
    assert_equal hash.delete("a"), "foo"
    assert_equal hash.delete("a"), nil
  end

  def test_indifferent_select
    hash = ActiveSupport::HashWithIndifferentAccess.new(@strings).select { |k,v| v == 1 }

    assert_equal({ "a" => 1 }, hash)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash
  end

  def test_indifferent_select_returns_enumerator
    enum = ActiveSupport::HashWithIndifferentAccess.new(@strings).select
    assert_instance_of Enumerator, enum
  end

  def test_indifferent_select_returns_a_hash_when_unchanged
    hash = ActiveSupport::HashWithIndifferentAccess.new(@strings).select { |k,v| true }

    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash
  end

  def test_indifferent_select_bang
    indifferent_strings = ActiveSupport::HashWithIndifferentAccess.new(@strings)
    indifferent_strings.select! { |k,v| v == 1 }

    assert_equal({ "a" => 1 }, indifferent_strings)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, indifferent_strings
  end

  def test_indifferent_reject
    hash = ActiveSupport::HashWithIndifferentAccess.new(@strings).reject { |k,v| v != 1 }

    assert_equal({ "a" => 1 }, hash)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash
  end

  def test_indifferent_reject_returns_enumerator
    enum = ActiveSupport::HashWithIndifferentAccess.new(@strings).reject
    assert_instance_of Enumerator, enum
  end

  def test_indifferent_reject_bang
    indifferent_strings = ActiveSupport::HashWithIndifferentAccess.new(@strings)
    indifferent_strings.reject! { |k,v| v != 1 }

    assert_equal({ "a" => 1 }, indifferent_strings)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, indifferent_strings
  end

  def test_indifferent_to_hash
    # Should convert to a Hash with String keys.
    assert_equal @strings, @mixed.with_indifferent_access.to_hash

    # Should preserve the default value.
    mixed_with_default = @mixed.dup
    mixed_with_default.default = "1234"
    roundtrip = mixed_with_default.with_indifferent_access.to_hash
    assert_equal @strings, roundtrip
    assert_equal "1234", roundtrip.default

    # Ensure nested hashes are not HashWithIndiffereneAccess
    new_to_hash = @nested_mixed.with_indifferent_access.to_hash
    assert_not new_to_hash.instance_of?(HashWithIndifferentAccess)
    assert_not new_to_hash["a"].instance_of?(HashWithIndifferentAccess)
    assert_not new_to_hash["a"]["b"].instance_of?(HashWithIndifferentAccess)
  end

  def test_lookup_returns_the_same_object_that_is_stored_in_hash_indifferent_access
    hash = HashWithIndifferentAccess.new { |h, k| h[k] = [] }
    hash[:a] << 1

    assert_equal [1], hash[:a]
  end

  def test_with_indifferent_access_has_no_side_effects_on_existing_hash
    hash = { content: [{ :foo => :bar, "bar" => "baz" }] }
    hash.with_indifferent_access

    assert_equal [:foo, "bar"], hash[:content].first.keys
  end

  def test_indifferent_hash_with_array_of_hashes
    hash = { "urls" => { "url" => [ { "address" => "1" }, { "address" => "2" } ] } }.with_indifferent_access
    assert_equal "1", hash[:urls][:url].first[:address]

    hash = hash.to_hash
    assert_not hash.instance_of?(HashWithIndifferentAccess)
    assert_not hash["urls"].instance_of?(HashWithIndifferentAccess)
    assert_not hash["urls"]["url"].first.instance_of?(HashWithIndifferentAccess)
  end

  def test_should_preserve_array_subclass_when_value_is_array
    array = SubclassingArray.new
    array << { "address" => "1" }
    hash = { "urls" => { "url" => array } }.with_indifferent_access
    assert_equal SubclassingArray, hash[:urls][:url].class
  end

  def test_should_preserve_array_class_when_hash_value_is_frozen_array
    array = SubclassingArray.new
    array << { "address" => "1" }
    hash = { "urls" => { "url" => array.freeze } }.with_indifferent_access
    assert_equal SubclassingArray, hash[:urls][:url].class
  end

  def test_stringify_and_symbolize_keys_on_indifferent_preserves_hash
    h = HashWithIndifferentAccess.new
    h[:first] = 1
    h = h.stringify_keys
    assert_equal 1, h["first"]
    h = HashWithIndifferentAccess.new
    h["first"] = 1
    h = h.symbolize_keys
    assert_equal 1, h[:first]
  end

  def test_deep_stringify_and_deep_symbolize_keys_on_indifferent_preserves_hash
    h = HashWithIndifferentAccess.new
    h[:first] = 1
    h = h.deep_stringify_keys
    assert_equal 1, h["first"]
    h = HashWithIndifferentAccess.new
    h["first"] = 1
    h = h.deep_symbolize_keys
    assert_equal 1, h[:first]
  end

  def test_to_options_on_indifferent_preserves_hash
    h = HashWithIndifferentAccess.new
    h["first"] = 1
    h.to_options!
    assert_equal 1, h["first"]
  end

  def test_to_options_on_indifferent_preserves_works_as_hash_with_dup
    h = HashWithIndifferentAccess.new(a: { b: "b" })
    dup = h.dup

    dup[:a][:c] = "c"
    assert_equal "c", h[:a][:c]
  end

  def test_indifferent_sub_hashes
    h = { "user" => { "id" => 5 } }.with_indifferent_access
    ["user", :user].each { |user| [:id, "id"].each { |id| assert_equal 5, h[user][id], "h[#{user.inspect}][#{id.inspect}] should be 5" } }

    h = { user: { id: 5 } }.with_indifferent_access
    ["user", :user].each { |user| [:id, "id"].each { |id| assert_equal 5, h[user][id], "h[#{user.inspect}][#{id.inspect}] should be 5" } }
  end

  def test_indifferent_duplication
    # Should preserve default value
    h = HashWithIndifferentAccess.new
    h.default = "1234"
    assert_equal h.default, h.dup.default

    # Should preserve class for subclasses
    h = IndifferentHash.new
    assert_equal h.class, h.dup.class
  end

  def test_nested_dig_indifferent_access
    skip if RUBY_VERSION < "2.3.0"
    data = { "this" => { "views" => 1234 } }.with_indifferent_access
    assert_equal 1234, data.dig(:this, :views)
  end

  def test_assert_valid_keys
    assert_nothing_raised do
      { failure: "stuff", funny: "business" }.assert_valid_keys([ :failure, :funny ])
      { failure: "stuff", funny: "business" }.assert_valid_keys(:failure, :funny)
    end
    # not all valid keys are required to be present
    assert_nothing_raised do
      { failure: "stuff", funny: "business" }.assert_valid_keys([ :failure, :funny, :sunny ])
      { failure: "stuff", funny: "business" }.assert_valid_keys(:failure, :funny, :sunny)
    end

    exception = assert_raise ArgumentError do
      { failore: "stuff", funny: "business" }.assert_valid_keys([ :failure, :funny ])
    end
    assert_equal "Unknown key: :failore. Valid keys are: :failure, :funny", exception.message

    exception = assert_raise ArgumentError do
      { failore: "stuff", funny: "business" }.assert_valid_keys(:failure, :funny)
    end
    assert_equal "Unknown key: :failore. Valid keys are: :failure, :funny", exception.message

    exception = assert_raise ArgumentError do
      { failore: "stuff", funny: "business" }.assert_valid_keys([ :failure ])
    end
    assert_equal "Unknown key: :failore. Valid keys are: :failure", exception.message

    exception = assert_raise ArgumentError do
      { failore: "stuff", funny: "business" }.assert_valid_keys(:failure)
    end
    assert_equal "Unknown key: :failore. Valid keys are: :failure", exception.message
  end

  def test_assorted_keys_not_stringified
    original = { Object.new => 2, 1 => 2, [] => true }
    indiff = original.with_indifferent_access
    assert(!indiff.keys.any? { |k| k.kind_of? String }, "A key was converted to a string!")
  end

  def test_deep_merge
    hash_1 = { a: "a", b: "b", c: { c1: "c1", c2: "c2", c3: { d1: "d1" } } }
    hash_2 = { a: 1, c: { c1: 2, c3: { d2: "d2" } } }
    expected = { a: 1, b: "b", c: { c1: 2, c2: "c2", c3: { d1: "d1", d2: "d2" } } }
    assert_equal expected, hash_1.deep_merge(hash_2)

    hash_1.deep_merge!(hash_2)
    assert_equal expected, hash_1
  end

  def test_deep_merge_with_block
    hash_1 = { a: "a", b: "b", c: { c1: "c1", c2: "c2", c3: { d1: "d1" } } }
    hash_2 = { a: 1, c: { c1: 2, c3: { d2: "d2" } } }
    expected = { a: [:a, "a", 1], b: "b", c: { c1: [:c1, "c1", 2], c2: "c2", c3: { d1: "d1", d2: "d2" } } }
    assert_equal(expected, hash_1.deep_merge(hash_2) { |k,o,n| [k, o, n] })

    hash_1.deep_merge!(hash_2) { |k,o,n| [k, o, n] }
    assert_equal expected, hash_1
  end

  def test_deep_merge_with_falsey_values
    hash_1 = { e: false }
    hash_2 = { e: "e" }
    expected = { e: [:e, false, "e"] }
    assert_equal(expected, hash_1.deep_merge(hash_2) { |k, o, n| [k, o, n] })

    hash_1.deep_merge!(hash_2) { |k, o, n| [k, o, n] }
    assert_equal expected, hash_1
  end

  def test_deep_merge_on_indifferent_access
    hash_1 = HashWithIndifferentAccess.new(a: "a", b: "b", c: { c1: "c1", c2: "c2", c3: { d1: "d1" } })
    hash_2 = HashWithIndifferentAccess.new(a: 1, c: { c1: 2, c3: { d2: "d2" } })
    hash_3 = { a: 1, c: { c1: 2, c3: { d2: "d2" } } }
    expected = { "a" => 1, "b" => "b", "c" => { "c1" => 2, "c2" => "c2", "c3" => { "d1" => "d1", "d2" => "d2" } } }
    assert_equal expected, hash_1.deep_merge(hash_2)
    assert_equal expected, hash_1.deep_merge(hash_3)

    hash_1.deep_merge!(hash_2)
    assert_equal expected, hash_1
  end

  def test_store_on_indifferent_access
    hash = HashWithIndifferentAccess.new
    hash.store(:test1, 1)
    hash.store("test1", 11)
    hash[:test2] = 2
    hash["test2"] = 22
    expected = { "test1" => 11, "test2" => 22 }
    assert_equal expected, hash
  end

  def test_constructor_on_indifferent_access
    hash = HashWithIndifferentAccess[:foo, 1]
    assert_equal 1, hash[:foo]
    assert_equal 1, hash["foo"]
    hash[:foo] = 3
    assert_equal 3, hash[:foo]
    assert_equal 3, hash["foo"]
  end

  def test_reverse_merge
    defaults = { a: "x", b: "y", c: 10 }.freeze
    options  = { a: 1, b: 2 }
    expected = { a: 1, b: 2, c: 10 }

    # Should merge defaults into options, creating a new hash.
    assert_equal expected, options.reverse_merge(defaults)
    assert_not_equal expected, options

    # Should merge! defaults into options, replacing options.
    merged = options.dup
    assert_equal expected, merged.reverse_merge!(defaults)
    assert_equal expected, merged

    # Should be an alias for reverse_merge!
    merged = options.dup
    assert_equal expected, merged.reverse_update(defaults)
    assert_equal expected, merged
  end

  def test_slice
    original = { a: "x", b: "y", c: 10 }
    expected = { a: "x", b: "y" }

    # Should return a new hash with only the given keys.
    assert_equal expected, original.slice(:a, :b)
    assert_not_equal expected, original
  end

  def test_slice_inplace
    original = { a: "x", b: "y", c: 10 }
    expected = { c: 10 }

    # Should replace the hash with only the given keys.
    assert_equal expected, original.slice!(:a, :b)
  end

  def test_slice_with_an_array_key
    original = { :a => "x", :b => "y", :c => 10, [:a, :b] => "an array key" }
    expected = { [:a, :b] => "an array key", :c => 10 }

    # Should return a new hash with only the given keys when given an array key.
    assert_equal expected, original.slice([:a, :b], :c)
    assert_not_equal expected, original
  end

  def test_slice_inplace_with_an_array_key
    original = { :a => "x", :b => "y", :c => 10, [:a, :b] => "an array key" }
    expected = { a: "x", b: "y" }

    # Should replace the hash with only the given keys when given an array key.
    assert_equal expected, original.slice!([:a, :b], :c)
  end

  def test_slice_with_splatted_keys
    original = { :a => "x", :b => "y", :c => 10, [:a, :b] => "an array key" }
    expected = { a: "x", b: "y" }

    # Should grab each of the splatted keys.
    assert_equal expected, original.slice(*[:a, :b])
  end

  def test_indifferent_slice
    original = { a: "x", b: "y", c: 10 }.with_indifferent_access
    expected = { a: "x", b: "y" }.with_indifferent_access

    [["a", "b"], [:a, :b]].each do |keys|
      # Should return a new hash with only the given keys.
      assert_equal expected, original.slice(*keys), keys.inspect
      assert_not_equal expected, original
    end
  end

  def test_indifferent_slice_inplace
    original = { a: "x", b: "y", c: 10 }.with_indifferent_access
    expected = { c: 10 }.with_indifferent_access

    [["a", "b"], [:a, :b]].each do |keys|
      # Should replace the hash with only the given keys.
      copy = original.dup
      assert_equal expected, copy.slice!(*keys)
    end
  end

  def test_indifferent_slice_access_with_symbols
    original = { "login" => "bender", "password" => "shiny", "stuff" => "foo" }
    original = original.with_indifferent_access

    slice = original.slice(:login, :password)

    assert_equal "bender", slice[:login]
    assert_equal "bender", slice["login"]
  end

  def test_slice_bang_does_not_override_default
    hash = Hash.new(0)
    hash.update(a: 1, b: 2)

    hash.slice!(:a)

    assert_equal 0, hash[:c]
  end

  def test_slice_bang_does_not_override_default_proc
    hash = Hash.new { |h, k| h[k] = [] }
    hash.update(a: 1, b: 2)

    hash.slice!(:a)

    assert_equal [], hash[:c]
  end

  def test_extract
    original = { a: 1, b: 2, c: 3, d: 4 }
    expected = { a: 1, b: 2 }
    remaining = { c: 3, d: 4 }

    assert_equal expected, original.extract!(:a, :b, :x)
    assert_equal remaining, original
  end

  def test_extract_nils
    original = { a: nil, b: nil }
    expected = { a: nil }
    extracted = original.extract!(:a, :x)

    assert_equal expected, extracted
    assert_equal nil, extracted[:a]
    assert_equal nil, extracted[:x]
  end

  def test_indifferent_extract
    original = { :a => 1, "b" => 2, :c => 3, "d" => 4 }.with_indifferent_access
    expected = { a: 1, b: 2 }.with_indifferent_access
    remaining = { c: 3, d: 4 }.with_indifferent_access

    [["a", "b"], [:a, :b]].each do |keys|
      copy = original.dup
      assert_equal expected, copy.extract!(*keys)
      assert_equal remaining, copy
    end
  end

  def test_except
    original = { a: "x", b: "y", c: 10 }
    expected = { a: "x", b: "y" }

    # Should return a new hash without the given keys.
    assert_equal expected, original.except(:c)
    assert_not_equal expected, original

    # Should replace the hash without the given keys.
    assert_equal expected, original.except!(:c)
    assert_equal expected, original
  end

  def test_except_with_more_than_one_argument
    original = { a: "x", b: "y", c: 10 }
    expected = { a: "x" }

    assert_equal expected, original.except(:b, :c)

    assert_equal expected, original.except!(:b, :c)
    assert_equal expected, original
  end

  def test_except_with_original_frozen
    original = { a: "x", b: "y" }
    original.freeze
    assert_nothing_raised { original.except(:a) }

    assert_raise(RuntimeError) { original.except!(:a) }
  end

  def test_except_does_not_delete_values_in_original
    original = { a: "x", b: "y" }
    assert_not_called(original, :delete) do
      original.except(:a)
    end
  end

  def test_compact
    hash_contain_nil_value = @symbols.merge(z: nil)
    hash_with_only_nil_values = { a: nil, b: nil }

    h = hash_contain_nil_value.dup
    assert_equal(@symbols, h.compact)
    assert_equal(hash_contain_nil_value, h)

    h = hash_with_only_nil_values.dup
    assert_equal({}, h.compact)
    assert_equal(hash_with_only_nil_values, h)

    h = @symbols.dup
    assert_equal(@symbols, h.compact)
    assert_equal(@symbols, h)
  end

  def test_compact!
    hash_contain_nil_value = @symbols.merge(z: nil)
    hash_with_only_nil_values = { a: nil, b: nil }

    h = hash_contain_nil_value.dup
    assert_equal(@symbols, h.compact!)
    assert_equal(@symbols, h)

    h = hash_with_only_nil_values.dup
    assert_equal({}, h.compact!)
    assert_equal({}, h)

    h = @symbols.dup
    assert_equal(nil, h.compact!)
    assert_equal(@symbols, h)
  end

  def test_new_with_to_hash_conversion
    hash = HashWithIndifferentAccess.new(HashByConversion.new(a: 1))
    assert hash.key?("a")
    assert_equal 1, hash[:a]
  end

  def test_dup_with_default_proc
    hash = HashWithIndifferentAccess.new
    hash.default_proc = proc { |h, v| raise "walrus" }
    assert_nothing_raised { hash.dup }
  end

  def test_dup_with_default_proc_sets_proc
    hash = HashWithIndifferentAccess.new
    hash.default_proc = proc { |h, k| k + 1 }
    new_hash = hash.dup

    assert_equal 3, new_hash[2]

    new_hash.default = 2
    assert_equal 2, new_hash[:non_existent]
  end

  def test_to_hash_with_raising_default_proc
    hash = HashWithIndifferentAccess.new
    hash.default_proc = proc { |h, k| raise "walrus" }

    assert_nothing_raised { hash.to_hash }
  end

  def test_new_from_hash_copying_default_should_not_raise_when_default_proc_does
    hash = Hash.new
    hash.default_proc = proc { |h, k| raise "walrus" }

    assert_deprecated { HashWithIndifferentAccess.new_from_hash_copying_default(hash) }
  end

  def test_new_with_to_hash_conversion_copies_default
    normal_hash = Hash.new(3)
    normal_hash[:a] = 1

    hash = HashWithIndifferentAccess.new(HashByConversion.new(normal_hash))
    assert_equal 1, hash[:a]
    assert_equal 3, hash[:b]
  end

  def test_new_with_to_hash_conversion_copies_default_proc
    normal_hash = Hash.new { 1 + 2 }
    normal_hash[:a] = 1

    hash = HashWithIndifferentAccess.new(HashByConversion.new(normal_hash))
    assert_equal 1, hash[:a]
    assert_equal 3, hash[:b]
  end
end

class IWriteMyOwnXML
  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(indent: options[:indent])
    xml.instruct! unless options[:skip_instruct]
    xml.level_one do
      xml.tag!(:second_level, "content")
    end
  end
end

class HashExtToParamTests < ActiveSupport::TestCase
  class ToParam < String
    def to_param
      "#{self}-1"
    end
  end

  def test_string_hash
    assert_equal "", {}.to_param
    assert_equal "hello=world", { hello: "world" }.to_param
    assert_equal "hello=10", { "hello" => 10 }.to_param
    assert_equal "hello=world&say_bye=true", { :hello => "world", "say_bye" => true }.to_param
  end

  def test_number_hash
    assert_equal "10=20&30=40&50=60", { 10 => 20, 30 => 40, 50 => 60 }.to_param
  end

  def test_to_param_hash
    assert_equal "custom-1=param-1&custom2-1=param2-1", { ToParam.new("custom") => ToParam.new("param"), ToParam.new("custom2") => ToParam.new("param2") }.to_param
  end

  def test_to_param_hash_escapes_its_keys_and_values
    assert_equal "param+1=A+string+with+%2F+characters+%26+that+should+be+%3F+escaped", { "param 1" => "A string with / characters & that should be ? escaped" }.to_param
  end

  def test_to_param_orders_by_key_in_ascending_order
    assert_equal "a=2&b=1&c=0", Hash[*%w(b 1 c 0 a 2)].to_param
  end
end

class HashToXmlTest < ActiveSupport::TestCase
  def setup
    @xml_options = { root: :person, skip_instruct: true, indent: 0 }
  end

  def test_one_level
    xml = { name: "David", street: "Paulina" }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<street>Paulina</street>))
    assert xml.include?(%(<name>David</name>))
  end

  def test_one_level_dasherize_false
    xml = { name: "David", street_name: "Paulina" }.to_xml(@xml_options.merge(dasherize: false))
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<street_name>Paulina</street_name>))
    assert xml.include?(%(<name>David</name>))
  end

  def test_one_level_dasherize_true
    xml = { name: "David", street_name: "Paulina" }.to_xml(@xml_options.merge(dasherize: true))
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<street-name>Paulina</street-name>))
    assert xml.include?(%(<name>David</name>))
  end

  def test_one_level_camelize_true
    xml = { name: "David", street_name: "Paulina" }.to_xml(@xml_options.merge(camelize: true))
    assert_equal "<Person>", xml.first(8)
    assert xml.include?(%(<StreetName>Paulina</StreetName>))
    assert xml.include?(%(<Name>David</Name>))
  end

  def test_one_level_camelize_lower
    xml = { name: "David", street_name: "Paulina" }.to_xml(@xml_options.merge(camelize: :lower))
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<streetName>Paulina</streetName>))
    assert xml.include?(%(<name>David</name>))
  end

  def test_one_level_with_types
    xml = { name: "David", street: "Paulina", age: 26, age_in_millis: 820497600000, moved_on: Date.new(2005, 11, 15), resident: :yes }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<street>Paulina</street>))
    assert xml.include?(%(<name>David</name>))
    assert xml.include?(%(<age type="integer">26</age>))
    assert xml.include?(%(<age-in-millis type="integer">820497600000</age-in-millis>))
    assert xml.include?(%(<moved-on type="date">2005-11-15</moved-on>))
    assert xml.include?(%(<resident type="symbol">yes</resident>))
  end

  def test_one_level_with_nils
    xml = { name: "David", street: "Paulina", age: nil }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<street>Paulina</street>))
    assert xml.include?(%(<name>David</name>))
    assert xml.include?(%(<age nil="true"/>))
  end

  def test_one_level_with_skipping_types
    xml = { name: "David", street: "Paulina", age: nil }.to_xml(@xml_options.merge(skip_types: true))
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<street>Paulina</street>))
    assert xml.include?(%(<name>David</name>))
    assert xml.include?(%(<age nil="true"/>))
  end

  def test_one_level_with_yielding
    xml = { name: "David", street: "Paulina" }.to_xml(@xml_options) do |x|
      x.creator("Rails")
    end

    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<street>Paulina</street>))
    assert xml.include?(%(<name>David</name>))
    assert xml.include?(%(<creator>Rails</creator>))
  end

  def test_two_levels
    xml = { name: "David", address: { street: "Paulina" } }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<address><street>Paulina</street></address>))
    assert xml.include?(%(<name>David</name>))
  end

  def test_two_levels_with_second_level_overriding_to_xml
    xml = { name: "David", address: { street: "Paulina" }, child: IWriteMyOwnXML.new }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<address><street>Paulina</street></address>))
    assert xml.include?(%(<level_one><second_level>content</second_level></level_one>))
  end

  def test_two_levels_with_array
    xml = { name: "David", addresses: [{ street: "Paulina" }, { street: "Evergreen" }] }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert xml.include?(%(<addresses type="array"><address>))
    assert xml.include?(%(<address><street>Paulina</street></address>))
    assert xml.include?(%(<address><street>Evergreen</street></address>))
    assert xml.include?(%(<name>David</name>))
  end

  def test_three_levels_with_array
    xml = { name: "David", addresses: [{ streets: [ { name: "Paulina" }, { name: "Paulina" } ] } ] }.to_xml(@xml_options)
    assert xml.include?(%(<addresses type="array"><address><streets type="array"><street><name>))
  end

  def test_timezoned_attributes
    xml = {
      created_at: Time.utc(1999,2,2),
      local_created_at: Time.utc(1999,2,2).in_time_zone("Eastern Time (US & Canada)")
    }.to_xml(@xml_options)
    assert_match %r{<created-at type=\"dateTime\">1999-02-02T00:00:00Z</created-at>}, xml
    assert_match %r{<local-created-at type=\"dateTime\">1999-02-01T19:00:00-05:00</local-created-at>}, xml
  end

  def test_multiple_records_from_xml_with_attributes_other_than_type_ignores_them_without_exploding
    topics_xml = <<-EOT
      <topics type="array" page="1" page-count="1000" per-page="2">
        <topic>
          <title>The First Topic</title>
          <author-name>David</author-name>
          <id type="integer">1</id>
          <approved type="boolean">false</approved>
          <replies-count type="integer">0</replies-count>
          <replies-close-in type="integer">2592000000</replies-close-in>
          <written-on type="date">2003-07-16</written-on>
          <viewed-at type="datetime">2003-07-16T09:28:00+0000</viewed-at>
          <content>Have a nice day</content>
          <author-email-address>david@loudthinking.com</author-email-address>
          <parent-id nil="true"></parent-id>
        </topic>
        <topic>
          <title>The Second Topic</title>
          <author-name>Jason</author-name>
          <id type="integer">1</id>
          <approved type="boolean">false</approved>
          <replies-count type="integer">0</replies-count>
          <replies-close-in type="integer">2592000000</replies-close-in>
          <written-on type="date">2003-07-16</written-on>
          <viewed-at type="datetime">2003-07-16T09:28:00+0000</viewed-at>
          <content>Have a nice day</content>
          <author-email-address>david@loudthinking.com</author-email-address>
          <parent-id></parent-id>
        </topic>
      </topics>
    EOT

    expected_topic_hash = {
      title: "The First Topic",
      author_name: "David",
      id: 1,
      approved: false,
      replies_count: 0,
      replies_close_in: 2592000000,
      written_on: Date.new(2003, 7, 16),
      viewed_at: Time.utc(2003, 7, 16, 9, 28),
      content: "Have a nice day",
      author_email_address: "david@loudthinking.com",
      parent_id: nil
    }.stringify_keys

    assert_equal expected_topic_hash, Hash.from_xml(topics_xml)["topics"].first
  end

  def test_single_record_from_xml
    topic_xml = <<-EOT
      <topic>
        <title>The First Topic</title>
        <author-name>David</author-name>
        <id type="integer">1</id>
        <approved type="boolean"> true </approved>
        <replies-count type="integer">0</replies-count>
        <replies-close-in type="integer">2592000000</replies-close-in>
        <written-on type="date">2003-07-16</written-on>
        <viewed-at type="datetime">2003-07-16T09:28:00+0000</viewed-at>
        <author-email-address>david@loudthinking.com</author-email-address>
        <parent-id></parent-id>
        <ad-revenue type="decimal">1.5</ad-revenue>
        <optimum-viewing-angle type="float">135</optimum-viewing-angle>
      </topic>
    EOT

    expected_topic_hash = {
      title: "The First Topic",
      author_name: "David",
      id: 1,
      approved: true,
      replies_count: 0,
      replies_close_in: 2592000000,
      written_on: Date.new(2003, 7, 16),
      viewed_at: Time.utc(2003, 7, 16, 9, 28),
      author_email_address: "david@loudthinking.com",
      parent_id: nil,
      ad_revenue: BigDecimal("1.50"),
      optimum_viewing_angle: 135.0,
    }.stringify_keys

    assert_equal expected_topic_hash, Hash.from_xml(topic_xml)["topic"]
  end

  def test_single_record_from_xml_with_nil_values
    topic_xml = <<-EOT
      <topic>
        <title></title>
        <id type="integer"></id>
        <approved type="boolean"></approved>
        <written-on type="date"></written-on>
        <viewed-at type="datetime"></viewed-at>
        <parent-id></parent-id>
      </topic>
    EOT

    expected_topic_hash = {
      title: nil,
      id: nil,
      approved: nil,
      written_on: nil,
      viewed_at: nil,
      parent_id: nil
    }.stringify_keys

    assert_equal expected_topic_hash, Hash.from_xml(topic_xml)["topic"]
  end

  def test_multiple_records_from_xml
    topics_xml = <<-EOT
      <topics type="array">
        <topic>
          <title>The First Topic</title>
          <author-name>David</author-name>
          <id type="integer">1</id>
          <approved type="boolean">false</approved>
          <replies-count type="integer">0</replies-count>
          <replies-close-in type="integer">2592000000</replies-close-in>
          <written-on type="date">2003-07-16</written-on>
          <viewed-at type="datetime">2003-07-16T09:28:00+0000</viewed-at>
          <content>Have a nice day</content>
          <author-email-address>david@loudthinking.com</author-email-address>
          <parent-id nil="true"></parent-id>
        </topic>
        <topic>
          <title>The Second Topic</title>
          <author-name>Jason</author-name>
          <id type="integer">1</id>
          <approved type="boolean">false</approved>
          <replies-count type="integer">0</replies-count>
          <replies-close-in type="integer">2592000000</replies-close-in>
          <written-on type="date">2003-07-16</written-on>
          <viewed-at type="datetime">2003-07-16T09:28:00+0000</viewed-at>
          <content>Have a nice day</content>
          <author-email-address>david@loudthinking.com</author-email-address>
          <parent-id></parent-id>
        </topic>
      </topics>
    EOT

    expected_topic_hash = {
      title: "The First Topic",
      author_name: "David",
      id: 1,
      approved: false,
      replies_count: 0,
      replies_close_in: 2592000000,
      written_on: Date.new(2003, 7, 16),
      viewed_at: Time.utc(2003, 7, 16, 9, 28),
      content: "Have a nice day",
      author_email_address: "david@loudthinking.com",
      parent_id: nil
    }.stringify_keys

    assert_equal expected_topic_hash, Hash.from_xml(topics_xml)["topics"].first
  end

  def test_single_record_from_xml_with_attributes_other_than_type
    topic_xml = <<-EOT
    <rsp stat="ok">
      <photos page="1" pages="1" perpage="100" total="16">
        <photo id="175756086" owner="55569174@N00" secret="0279bf37a1" server="76" title="Colored Pencil PhotoBooth Fun" ispublic="1" isfriend="0" isfamily="0"/>
      </photos>
    </rsp>
    EOT

    expected_topic_hash = {
      id: "175756086",
      owner: "55569174@N00",
      secret: "0279bf37a1",
      server: "76",
      title: "Colored Pencil PhotoBooth Fun",
      ispublic: "1",
      isfriend: "0",
      isfamily: "0",
    }.stringify_keys

    assert_equal expected_topic_hash, Hash.from_xml(topic_xml)["rsp"]["photos"]["photo"]
  end

  def test_all_caps_key_from_xml
    test_xml = <<-EOT
      <ABC3XYZ>
        <TEST>Lorem Ipsum</TEST>
      </ABC3XYZ>
    EOT

    expected_hash = {
      "ABC3XYZ" => {
        "TEST" => "Lorem Ipsum"
      }
    }

    assert_equal expected_hash, Hash.from_xml(test_xml)
  end

  def test_empty_array_from_xml
    blog_xml = <<-XML
      <blog>
        <posts type="array"></posts>
      </blog>
    XML
    expected_blog_hash = { "blog" => { "posts" => [] } }
    assert_equal expected_blog_hash, Hash.from_xml(blog_xml)
  end

  def test_empty_array_with_whitespace_from_xml
    blog_xml = <<-XML
      <blog>
        <posts type="array">
        </posts>
      </blog>
    XML
    expected_blog_hash = { "blog" => { "posts" => [] } }
    assert_equal expected_blog_hash, Hash.from_xml(blog_xml)
  end

  def test_array_with_one_entry_from_xml
    blog_xml = <<-XML
      <blog>
        <posts type="array">
          <post>a post</post>
        </posts>
      </blog>
    XML
    expected_blog_hash = { "blog" => { "posts" => ["a post"] } }
    assert_equal expected_blog_hash, Hash.from_xml(blog_xml)
  end

  def test_array_with_multiple_entries_from_xml
    blog_xml = <<-XML
      <blog>
        <posts type="array">
          <post>a post</post>
          <post>another post</post>
        </posts>
      </blog>
    XML
    expected_blog_hash = { "blog" => { "posts" => ["a post", "another post"] } }
    assert_equal expected_blog_hash, Hash.from_xml(blog_xml)
  end

  def test_file_from_xml
    blog_xml = <<-XML
      <blog>
        <logo type="file" name="logo.png" content_type="image/png">
        </logo>
      </blog>
    XML
    hash = Hash.from_xml(blog_xml)
    assert hash.has_key?("blog")
    assert hash["blog"].has_key?("logo")

    file = hash["blog"]["logo"]
    assert_equal "logo.png", file.original_filename
    assert_equal "image/png", file.content_type
  end

  def test_file_from_xml_with_defaults
    blog_xml = <<-XML
      <blog>
        <logo type="file">
        </logo>
      </blog>
    XML
    file = Hash.from_xml(blog_xml)["blog"]["logo"]
    assert_equal "untitled", file.original_filename
    assert_equal "application/octet-stream", file.content_type
  end

  def test_tag_with_attrs_and_whitespace
    xml = <<-XML
      <blog name="bacon is the best">
      </blog>
    XML
    hash = Hash.from_xml(xml)
    assert_equal "bacon is the best", hash["blog"]["name"]
  end

  def test_empty_cdata_from_xml
    xml = "<data><![CDATA[]]></data>"

    assert_equal "", Hash.from_xml(xml)["data"]
  end

  def test_xsd_like_types_from_xml
    bacon_xml = <<-EOT
    <bacon>
      <weight type="double">0.5</weight>
      <price type="decimal">12.50</price>
      <chunky type="boolean"> 1 </chunky>
      <expires-at type="dateTime">2007-12-25T12:34:56+0000</expires-at>
      <notes type="string"></notes>
      <illustration type="base64Binary">YmFiZS5wbmc=</illustration>
      <caption type="binary" encoding="base64">VGhhdCdsbCBkbywgcGlnLg==</caption>
    </bacon>
    EOT

    expected_bacon_hash = {
      weight: 0.5,
      chunky: true,
      price: BigDecimal("12.50"),
      expires_at: Time.utc(2007,12,25,12,34,56),
      notes: "",
      illustration: "babe.png",
      caption: "That'll do, pig."
    }.stringify_keys

    assert_equal expected_bacon_hash, Hash.from_xml(bacon_xml)["bacon"]
  end

  def test_type_trickles_through_when_unknown
    product_xml = <<-EOT
    <product>
      <weight type="double">0.5</weight>
      <image type="ProductImage"><filename>image.gif</filename></image>

    </product>
    EOT

    expected_product_hash = {
      weight: 0.5,
      image: { "type" => "ProductImage", "filename" => "image.gif" },
    }.stringify_keys

    assert_equal expected_product_hash, Hash.from_xml(product_xml)["product"]
  end

  def test_from_xml_raises_on_disallowed_type_attributes
    assert_raise ActiveSupport::XMLConverter::DisallowedType do
      Hash.from_xml '<product><name type="foo">value</name></product>', %w(foo)
    end
  end

  def test_from_xml_disallows_symbol_and_yaml_types_by_default
    assert_raise ActiveSupport::XMLConverter::DisallowedType do
      Hash.from_xml '<product><name type="symbol">value</name></product>'
    end

    assert_raise ActiveSupport::XMLConverter::DisallowedType do
      Hash.from_xml '<product><name type="yaml">value</name></product>'
    end
  end

  def test_from_xml_array_one
    expected = { "numbers" => { "type" => "Array", "value" => "1" } }
    assert_equal expected, Hash.from_xml('<numbers type="Array"><value>1</value></numbers>')
  end

  def test_from_xml_array_many
    expected = { "numbers" => { "type" => "Array", "value" => [ "1", "2" ] } }
    assert_equal expected, Hash.from_xml('<numbers type="Array"><value>1</value><value>2</value></numbers>')
  end

  def test_from_trusted_xml_allows_symbol_and_yaml_types
    expected = { "product" => { "name" => :value } }
    assert_equal expected, Hash.from_trusted_xml('<product><name type="symbol">value</name></product>')
    assert_equal expected, Hash.from_trusted_xml('<product><name type="yaml">:value</name></product>')
  end

  def test_should_use_default_proc_for_unknown_key
    hash_wia = HashWithIndifferentAccess.new { 1 +  2 }
    assert_equal 3, hash_wia[:new_key]
  end

  def test_should_return_nil_if_no_key_is_supplied
    hash_wia = HashWithIndifferentAccess.new { 1 +  2 }
    assert_equal nil, hash_wia.default
  end

  def test_should_use_default_value_for_unknown_key
    hash_wia = HashWithIndifferentAccess.new(3)
    assert_equal 3, hash_wia[:new_key]
  end

  def test_should_use_default_value_if_no_key_is_supplied
    hash_wia = HashWithIndifferentAccess.new(3)
    assert_equal 3, hash_wia.default
  end

  def test_should_nil_if_no_default_value_is_supplied
    hash_wia = HashWithIndifferentAccess.new
    assert_nil hash_wia.default
  end

  def test_should_return_dup_for_with_indifferent_access
    hash_wia = HashWithIndifferentAccess.new
    assert_equal hash_wia, hash_wia.with_indifferent_access
    assert_not_same hash_wia, hash_wia.with_indifferent_access
  end

  def test_allows_setting_frozen_array_values_with_indifferent_access
    value = [1, 2, 3].freeze
    hash = HashWithIndifferentAccess.new
    hash[:key] = value
    assert_equal hash[:key], value
  end

  def test_should_copy_the_default_value_when_converting_to_hash_with_indifferent_access
    hash = Hash.new(3)
    hash_wia = hash.with_indifferent_access
    assert_equal 3, hash_wia.default
  end

  def test_should_copy_the_default_proc_when_converting_to_hash_with_indifferent_access
    hash = Hash.new do
      2 + 1
    end
    assert_equal 3, hash[:foo]

    hash_wia = hash.with_indifferent_access
    assert_equal 3, hash_wia[:foo]
    assert_equal 3, hash_wia[:bar]
  end

  # The XML builder seems to fail miserably when trying to tag something
  # with the same name as a Kernel method (throw, test, loop, select ...)
  def test_kernel_method_names_to_xml
    hash     = { throw: { ball: "red" } }
    expected = "<person><throw><ball>red</ball></throw></person>"

    assert_nothing_raised do
      assert_equal expected, hash.to_xml(@xml_options)
    end
  end

  def test_empty_string_works_for_typecast_xml_value
    assert_nothing_raised do
      ActiveSupport::XMLConverter.new("").to_h
    end
  end

  def test_escaping_to_xml
    hash = {
      bare_string: "First & Last Name",
      pre_escaped_string: "First &amp; Last Name"
    }.stringify_keys

    expected_xml = "<person><bare-string>First &amp; Last Name</bare-string><pre-escaped-string>First &amp;amp; Last Name</pre-escaped-string></person>"
    assert_equal expected_xml, hash.to_xml(@xml_options)
  end

  def test_unescaping_from_xml
    xml_string = "<person><bare-string>First &amp; Last Name</bare-string><pre-escaped-string>First &amp;amp; Last Name</pre-escaped-string></person>"
    expected_hash = {
      bare_string: "First & Last Name",
      pre_escaped_string: "First &amp; Last Name"
    }.stringify_keys
    assert_equal expected_hash, Hash.from_xml(xml_string)["person"]
  end

  def test_roundtrip_to_xml_from_xml
    hash = {
      bare_string: "First & Last Name",
      pre_escaped_string: "First &amp; Last Name"
    }.stringify_keys

    assert_equal hash, Hash.from_xml(hash.to_xml(@xml_options))["person"]
  end

  def test_datetime_xml_type_with_utc_time
    alert_xml = <<-XML
      <alert>
        <alert_at type="datetime">2008-02-10T15:30:45Z</alert_at>
      </alert>
    XML
    alert_at = Hash.from_xml(alert_xml)["alert"]["alert_at"]
    assert alert_at.utc?
    assert_equal Time.utc(2008, 2, 10, 15, 30, 45), alert_at
  end

  def test_datetime_xml_type_with_non_utc_time
    alert_xml = <<-XML
      <alert>
        <alert_at type="datetime">2008-02-10T10:30:45-05:00</alert_at>
      </alert>
    XML
    alert_at = Hash.from_xml(alert_xml)["alert"]["alert_at"]
    assert alert_at.utc?
    assert_equal Time.utc(2008, 2, 10, 15, 30, 45), alert_at
  end

  def test_datetime_xml_type_with_far_future_date
    alert_xml = <<-XML
      <alert>
        <alert_at type="datetime">2050-02-10T15:30:45Z</alert_at>
      </alert>
    XML
    alert_at = Hash.from_xml(alert_xml)["alert"]["alert_at"]
    assert alert_at.utc?
    assert_equal 2050,  alert_at.year
    assert_equal 2,     alert_at.month
    assert_equal 10,    alert_at.day
    assert_equal 15,    alert_at.hour
    assert_equal 30,    alert_at.min
    assert_equal 45,    alert_at.sec
  end

  def test_to_xml_dups_options
    options = { skip_instruct: true }
    {}.to_xml(options)
    # :builder, etc, shouldn't be added to options
    assert_equal({ skip_instruct: true }, options)
  end

  def test_expansion_count_is_limited
    expected =
      case ActiveSupport::XmlMini.backend.name
      when "ActiveSupport::XmlMini_REXML";        RuntimeError
      when "ActiveSupport::XmlMini_Nokogiri";     Nokogiri::XML::SyntaxError
      when "ActiveSupport::XmlMini_NokogiriSAX";  RuntimeError
      when "ActiveSupport::XmlMini_LibXML";       LibXML::XML::Error
      when "ActiveSupport::XmlMini_LibXMLSAX";    LibXML::XML::Error
      end

    assert_raise expected do
      attack_xml = <<-EOT
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE member [
        <!ENTITY a "&b;&b;&b;&b;&b;&b;&b;&b;&b;&b;">
        <!ENTITY b "&c;&c;&c;&c;&c;&c;&c;&c;&c;&c;">
        <!ENTITY c "&d;&d;&d;&d;&d;&d;&d;&d;&d;&d;">
        <!ENTITY d "&e;&e;&e;&e;&e;&e;&e;&e;&e;&e;">
        <!ENTITY e "&f;&f;&f;&f;&f;&f;&f;&f;&f;&f;">
        <!ENTITY f "&g;&g;&g;&g;&g;&g;&g;&g;&g;&g;">
        <!ENTITY g "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx">
      ]>
      <member>
      &a;
      </member>
      EOT
      Hash.from_xml(attack_xml)
    end
  end
end
