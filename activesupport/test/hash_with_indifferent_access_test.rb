# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/core_ext/hash"
require "bigdecimal"
require "active_support/core_ext/string/access"
require "active_support/ordered_hash"
require "active_support/core_ext/object/conversions"
require "active_support/core_ext/object/deep_dup"
require "active_support/inflections"

class HashWithIndifferentAccessTest < ActiveSupport::TestCase
  HashWithIndifferentAccess = ActiveSupport::HashWithIndifferentAccess

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
  end

  def test_symbolize_keys_for_hash_with_indifferent_access
    assert_instance_of Hash, @symbols.with_indifferent_access.symbolize_keys
    assert_equal @symbols, @symbols.with_indifferent_access.symbolize_keys
    assert_equal @symbols, @strings.with_indifferent_access.symbolize_keys
    assert_equal @symbols, @mixed.with_indifferent_access.symbolize_keys
  end

  def test_to_options_for_hash_with_indifferent_access
    assert_instance_of Hash, @symbols.with_indifferent_access.to_options
    assert_equal @symbols, @symbols.with_indifferent_access.to_options
    assert_equal @symbols, @strings.with_indifferent_access.to_options
    assert_equal @symbols, @mixed.with_indifferent_access.to_options
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

  def test_indifferent_fetch_values
    @mixed = @mixed.with_indifferent_access

    assert_equal [1, 2], @mixed.fetch_values("a", "b")
    assert_equal [1, 2], @mixed.fetch_values(:a, :b)
    assert_equal [1, 2], @mixed.fetch_values(:a, "b")
    assert_equal [1, "c"], @mixed.fetch_values(:a, :c) { |key| key }
    assert_raise(KeyError) { @mixed.fetch_values(:a, :c) }
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
    assert_nil hash[:d]
    assert_nil hash[:e]
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
    assert_nil hash[:d]
    assert_equal 1, hash[:e]
  end

  def test_indifferent_writing
    hash = HashWithIndifferentAccess.new
    hash[:a] = 1
    hash["b"] = 2
    hash[3] = 3

    assert_equal 1, hash["a"]
    assert_equal 2, hash["b"]
    assert_equal 1, hash[:a]
    assert_equal 2, hash[:b]
    assert_equal 3, hash[3]
  end

  def test_indifferent_update
    hash = HashWithIndifferentAccess.new
    hash[:a] = "a"
    hash["b"] = "b"

    updated_with_strings = hash.update(@strings)
    updated_with_symbols = hash.update(@symbols)
    updated_with_mixed = hash.update(@mixed)

    assert_equal 1, updated_with_strings[:a]
    assert_equal 1, updated_with_strings["a"]
    assert_equal 2, updated_with_strings["b"]

    assert_equal 1, updated_with_symbols[:a]
    assert_equal 2, updated_with_symbols["b"]
    assert_equal 2, updated_with_symbols[:b]

    assert_equal 1, updated_with_mixed[:a]
    assert_equal 2, updated_with_mixed["b"]

    assert [updated_with_strings, updated_with_symbols, updated_with_mixed].all? { |h| h.keys.size == 2 }
  end

  def test_update_with_multiple_arguments
    hash = HashWithIndifferentAccess.new
    hash.update({ "a" => 1 }, { "b" => 2 })

    assert_equal 1, hash["a"]
    assert_equal 2, hash["b"]
  end

  def test_update_with_to_hash_conversion
    hash = HashWithIndifferentAccess.new
    hash.update HashByConversion.new(a: 1)
    assert_equal 1, hash["a"]
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

  def test_merging_with_multiple_arguments
    hash = HashWithIndifferentAccess.new
    merged = hash.merge({ "a" => 1 }, { "b" => 2 })

    assert_equal 1, merged["a"]
    assert_equal 2, merged["b"]
  end

  def test_merge_with_to_hash_conversion
    hash = HashWithIndifferentAccess.new
    merged = hash.merge HashByConversion.new(a: 1)
    assert_equal 1, merged["a"]
  end

  def test_indifferent_replace
    hash = HashWithIndifferentAccess.new
    hash[:a] = 42

    replaced = hash.replace(b: 12)

    assert hash.key?("b")
    assert_not hash.key?(:a)
    assert_equal 12, hash[:b]
    assert_same hash, replaced
  end

  def test_replace_with_to_hash_conversion
    hash = HashWithIndifferentAccess.new
    hash[:a] = 42

    replaced = hash.replace(HashByConversion.new(b: 12))

    assert hash.key?("b")
    assert_not hash.key?(:a)
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

  def test_indifferent_with_defaults_aliases_reverse_merge
    hash = HashWithIndifferentAccess.new key: :old_value
    actual = hash.with_defaults key: :new_value
    assert_equal :old_value, actual[:key]

    hash = HashWithIndifferentAccess.new key: :old_value
    hash.with_defaults! key: :new_value
    assert_equal :old_value, hash[:key]
  end

  def test_indifferent_deleting
    get_hash = proc { { a: "foo" }.with_indifferent_access }
    hash = get_hash.call
    assert_equal "foo", hash.delete(:a)
    assert_nil hash.delete(:a)
    hash = get_hash.call
    assert_equal "foo", hash.delete("a")
    assert_nil hash.delete("a")
  end

  def test_indifferent_select
    hash = ActiveSupport::HashWithIndifferentAccess.new(@strings).select { |k, v| v == 1 }

    assert_equal({ "a" => 1 }, hash)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash
  end

  def test_indifferent_select_returns_enumerator
    enum = ActiveSupport::HashWithIndifferentAccess.new(@strings).select
    assert_instance_of Enumerator, enum
  end

  def test_indifferent_select_returns_a_hash_when_unchanged
    hash = ActiveSupport::HashWithIndifferentAccess.new(@strings).select { |k, v| true }

    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash
  end

  def test_indifferent_select_bang
    indifferent_strings = ActiveSupport::HashWithIndifferentAccess.new(@strings)
    indifferent_strings.select! { |k, v| v == 1 }

    assert_equal({ "a" => 1 }, indifferent_strings)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, indifferent_strings
  end

  def test_indifferent_reject
    hash = ActiveSupport::HashWithIndifferentAccess.new(@strings).reject { |k, v| v != 1 }

    assert_equal({ "a" => 1 }, hash)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash
  end

  def test_indifferent_reject_returns_enumerator
    enum = ActiveSupport::HashWithIndifferentAccess.new(@strings).reject
    assert_instance_of Enumerator, enum
  end

  def test_indifferent_reject_bang
    indifferent_strings = ActiveSupport::HashWithIndifferentAccess.new(@strings)
    indifferent_strings.reject! { |k, v| v != 1 }

    assert_equal({ "a" => 1 }, indifferent_strings)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, indifferent_strings
  end

  def test_indifferent_transform_keys
    hash = ActiveSupport::HashWithIndifferentAccess.new(@strings).transform_keys { |k| k * 2 }

    assert_equal({ "aa" => 1, "bb" => 2 }, hash)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash

    hash = ActiveSupport::HashWithIndifferentAccess.new(@strings).transform_keys { |k| k.to_sym }

    assert_equal(1, hash[:a])
    assert_equal(1, hash["a"])
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash
  end

  def test_indifferent_transform_keys_bang
    indifferent_strings = ActiveSupport::HashWithIndifferentAccess.new(@strings)
    indifferent_strings.transform_keys! { |k| k * 2 }

    assert_equal({ "aa" => 1, "bb" => 2 }, indifferent_strings)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, indifferent_strings

    indifferent_strings = ActiveSupport::HashWithIndifferentAccess.new(@strings)
    indifferent_strings.transform_keys! { |k| k.to_sym }

    assert_equal(1, indifferent_strings[:a])
    assert_equal(1, indifferent_strings["a"])
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, indifferent_strings
  end

  def test_indifferent_transform_values
    hash = ActiveSupport::HashWithIndifferentAccess.new(@strings).transform_values { |v| v * 2 }

    assert_equal({ "a" => 2, "b" => 4 }, hash)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash
  end

  def test_indifferent_transform_values_bang
    indifferent_strings = ActiveSupport::HashWithIndifferentAccess.new(@strings)
    indifferent_strings.transform_values! { |v| v * 2 }

    assert_equal({ "a" => 2, "b" => 4 }, indifferent_strings)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, indifferent_strings
  end

  def test_indifferent_assoc
    indifferent_strings = ActiveSupport::HashWithIndifferentAccess.new(@strings)
    key, value = indifferent_strings.assoc(:a)

    assert_equal("a", key)
    assert_equal(1, value)
  end

  def test_indifferent_compact
    hash_contain_nil_value = @strings.merge("z" => nil)
    hash = ActiveSupport::HashWithIndifferentAccess.new(hash_contain_nil_value)
    compacted_hash = hash.compact

    assert_equal(@strings, compacted_hash)
    assert_equal(hash_contain_nil_value, hash)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, compacted_hash

    empty_hash = ActiveSupport::HashWithIndifferentAccess.new
    compacted_hash = empty_hash.compact

    assert_equal compacted_hash, empty_hash

    non_empty_hash = ActiveSupport::HashWithIndifferentAccess.new(foo: :bar)
    compacted_hash = non_empty_hash.compact

    assert_equal compacted_hash, non_empty_hash
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

    # Ensure nested hashes are not HashWithIndifferentAccess
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
    data = { "this" => { "views" => 1234 } }.with_indifferent_access
    assert_equal 1234, data.dig(:this, :views)
  end

  def test_argless_default_with_existing_nil_key
    h = Hash.new(:default).merge(nil => "defined").with_indifferent_access

    assert_equal :default, h.default
  end

  def test_default_with_argument
    h = Hash.new { 5 }.merge(1 => 2).with_indifferent_access

    assert_equal 5, h.default(1)
  end

  def test_default_proc
    h = ActiveSupport::HashWithIndifferentAccess.new { |hash, key| key }

    assert_nil h.default
    assert_equal "foo", h.default("foo")
    assert_equal "foo", h.default(:foo)
  end

  def test_double_conversion_with_nil_key
    h = { nil => "defined" }.with_indifferent_access.with_indifferent_access

    assert_nil h[:undefined_key]
  end

  def test_assorted_keys_not_stringified
    original = { Object.new => 2, 1 => 2, [] => true }
    indiff = original.with_indifferent_access
    assert_not(indiff.keys.any? { |k| k.kind_of? String }, "A key was converted to a string!")
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

  def test_indifferent_without
    original = { a: "x", b: "y", c: 10 }.with_indifferent_access
    expected = { c: 10 }.with_indifferent_access

    [["a", "b"], [:a, :b]].each do |keys|
      # Should return a new hash without the given keys.
      assert_equal expected, original.without(*keys), keys.inspect
      assert_not_equal expected, original
    end
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

  def test_inheriting_from_top_level_hash_with_indifferent_access_preserves_ancestors_chain
    klass = Class.new(::HashWithIndifferentAccess)
    assert_equal ActiveSupport::HashWithIndifferentAccess, klass.ancestors[1]
  end

  def test_inheriting_from_hash_with_indifferent_access_properly_dumps_ivars
    klass = Class.new(::HashWithIndifferentAccess) do
      def initialize(*)
        @foo = "bar"
        super
      end
    end

    yaml_output = klass.new.to_yaml

    # `hash-with-ivars` was introduced in 2.0.9 (https://git.io/vyUQW)
    if Gem::Version.new(Psych::VERSION) >= Gem::Version.new("2.0.9")
      assert_includes yaml_output, "hash-with-ivars"
      assert_includes yaml_output, "@foo: bar"
    else
      assert_includes yaml_output, "hash"
    end
  end

  def test_should_use_default_proc_for_unknown_key
    hash_wia = HashWithIndifferentAccess.new { 1 + 2 }
    assert_equal 3, hash_wia[:new_key]
  end

  def test_should_return_nil_if_no_key_is_supplied
    hash_wia = HashWithIndifferentAccess.new { 1 + 2 }
    assert_nil hash_wia.default
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

  def test_should_copy_the_default_when_converting_non_hash_to_hash_with_indifferent_access
    non_hash = Object.new

    def non_hash.to_hash
      h = { foo: :bar }
      h.default = :baz
      h
    end

    hash_wia = HashWithIndifferentAccess.new(non_hash)
    assert_equal :bar, hash_wia[:foo]
    assert_equal :baz, hash_wia[:missing]
  end

  def test_should_copy_the_default_proc_when_converting_non_hash_to_hash_with_indifferent_access
    non_hash = Object.new

    def non_hash.to_hash
      h = { foo: :bar }
      h.default_proc = ->(hash, key) { hash[key] = :baz }
      h
    end

    hash_wia = HashWithIndifferentAccess.new(non_hash)
    assert_equal :bar, hash_wia[:foo]
    assert_equal :baz, hash_wia[:missing]
  end
end
