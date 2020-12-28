# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/hash"
require "bigdecimal"
require "active_support/core_ext/string/access"
require "active_support/ordered_hash"
require "active_support/core_ext/object/conversions"
require "active_support/core_ext/date/conversions"
require "active_support/core_ext/object/deep_dup"
require "active_support/inflections"

class HashExtTest < ActiveSupport::TestCase
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
    assert_respond_to h, :deep_transform_keys
    assert_respond_to h, :deep_transform_keys!
    assert_respond_to h, :deep_transform_values
    assert_respond_to h, :deep_transform_values!
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
    assert_respond_to h, :except
    assert_respond_to h, :except!
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
    assert_equal({ "a" => { b: { "c" => 3 } } }, @nested_mixed)
  end

  def test_deep_transform_values
    assert_equal({ "a" => "1", "b" => "2" }, @strings.deep_transform_values { |value| value.to_s })
    assert_equal({ "a" => { "b" => { "c" => "3" } } }, @nested_strings.deep_transform_values { |value| value.to_s })
    assert_equal({ "a" => [ { "b" => "2" }, { "c" => "3" }, "4" ] }, @string_array_of_hashes.deep_transform_values { |value| value.to_s })
  end

  def test_deep_transform_values_not_mutates
    transformed_hash = @nested_mixed.deep_dup
    transformed_hash.deep_transform_values { |value| value.to_s }
    assert_equal @nested_mixed, transformed_hash
  end

  def test_deep_transform_values!
    assert_equal({ "a" => "1", "b" => "2" }, @strings.deep_transform_values! { |value| value.to_s })
    assert_equal({ "a" => { "b" => { "c" => "3" } } }, @nested_strings.deep_transform_values! { |value| value.to_s })
    assert_equal({ "a" => [ { "b" => "2" }, { "c" => "3" }, "4" ] }, @string_array_of_hashes.deep_transform_values! { |value| value.to_s })
  end

  def test_deep_transform_values_with_bang_mutates
    transformed_hash = @nested_mixed.deep_dup
    transformed_hash.deep_transform_values! { |value| value.to_s }
    assert_equal({ "a" => { b: { "c" => "3" } } }, transformed_hash)
    assert_equal({ "a" => { b: { "c" => 3 } } }, @nested_mixed)
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
    assert_equal({ :a => 1, "b" => 2 }, @mixed)
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
    assert_equal({ "a" => { b: { "c" => 3 } } }, @nested_mixed)
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
    assert_equal({ :a => 1, "b" => 2 }, @mixed)
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
    assert_equal({ "a" => { b: { "c" => 3 } } }, @nested_mixed)
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

  def test_assert_required_keys
    assert_nothing_raised do
      { failure: "stuff", funny: "business" }.assert_required_keys([ :failure, :funny ])
      { failure: "stuff", funny: "business" }.assert_required_keys(:failure, :funny)
    end
    # keys that are not required may be present
    assert_nothing_raised do
      { failure: "stuff", funny: "business", sunny: "day" }.assert_required_keys([ :failure, :funny ])
      { failure: "stuff", funny: "business", sunny: "day" }.assert_required_keys(:failure, :funny)
    end

    exception = assert_raise ArgumentError do
      { failore: "stuff", funny: "business" }.assert_required_keys([ :failure, :funny ])
    end
    assert_equal "Missing required option(s): :failure", exception.message

    exception = assert_raise ArgumentError do
      { failore: "stuff", funny: "business" }.assert_required_keys(:failure, :funny)
    end
    assert_equal "Missing required option(s): :failure", exception.message

    exception = assert_raise ArgumentError do
      { failore: "stuff", funny: "business" }.assert_required_keys([ :failure ])
    end
    assert_equal "Missing required option(s): :failure", exception.message

    exception = assert_raise ArgumentError do
      { failore: "stuff", funny: "business" }.assert_required_keys(:failure)
    end
    assert_equal "Missing required option(s): :failure", exception.message
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
    assert_equal(expected, hash_1.deep_merge(hash_2) { |k, o, n| [k, o, n] })

    hash_1.deep_merge!(hash_2) { |k, o, n| [k, o, n] }
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

  def test_reverse_merge
    defaults = { d: 0, a: "x", b: "y", c: 10 }.freeze
    options  = { a: 1, b: 2 }
    expected = { d: 0, a: 1, b: 2, c: 10 }

    # Should merge defaults into options, creating a new hash.
    assert_equal expected, options.reverse_merge(defaults)
    assert_not_equal expected, options

    # Should merge! defaults into options, replacing options.
    merged = options.dup
    assert_equal expected, merged.reverse_merge!(defaults)
    assert_equal expected, merged

    # Make the order consistent with the non-overwriting reverse merge.
    assert_equal expected.keys, merged.keys

    # Should be an alias for reverse_merge!
    merged = options.dup
    assert_equal expected, merged.reverse_update(defaults)
    assert_equal expected, merged
  end

  def test_with_defaults_aliases_reverse_merge
    defaults = { a: "x", b: "y", c: 10 }.freeze
    options  = { a: 1, b: 2 }
    expected = { a: 1, b: 2, c: 10 }

    # Should be an alias for reverse_merge
    assert_equal expected, options.with_defaults(defaults)
    assert_not_equal expected, options

    # Should be an alias for reverse_merge!
    merged = options.dup
    assert_equal expected, merged.with_defaults!(defaults)
    assert_equal expected, merged
  end

  def test_slice_inplace
    original = { a: "x", b: "y", c: 10 }
    expected_return = { c: 10 }
    expected_original = { a: "x", b: "y" }

    # Should return a hash containing the removed key/value pairs.
    assert_equal expected_return, original.slice!(:a, :b)

    # Should replace the hash with only the given keys.
    assert_equal expected_original, original
  end

  def test_slice_inplace_with_an_array_key
    original = { :a => "x", :b => "y", :c => 10, [:a, :b] => "an array key" }
    expected = { a: "x", b: "y" }

    # Should replace the hash with only the given keys when given an array key.
    assert_equal expected, original.slice!([:a, :b], :c)
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
    remaining = { b: nil }
    extracted = original.extract!(:a, :x)

    assert_equal expected, extracted
    assert_nil extracted[:a]
    assert_nil extracted[:x]
    assert_equal remaining, original
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

    assert_raise(FrozenError) { original.except!(:a) }
  end

  def test_except_does_not_delete_values_in_original
    original = { a: "x", b: "y" }
    assert_not_called(original, :delete) do
      original.except(:a)
    end
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
    assert_includes xml, %(<street>Paulina</street>)
    assert_includes xml, %(<name>David</name>)
  end

  def test_one_level_dasherize_false
    xml = { name: "David", street_name: "Paulina" }.to_xml(@xml_options.merge(dasherize: false))
    assert_equal "<person>", xml.first(8)
    assert_includes xml, %(<street_name>Paulina</street_name>)
    assert_includes xml, %(<name>David</name>)
  end

  def test_one_level_dasherize_true
    xml = { name: "David", street_name: "Paulina" }.to_xml(@xml_options.merge(dasherize: true))
    assert_equal "<person>", xml.first(8)
    assert_includes xml, %(<street-name>Paulina</street-name>)
    assert_includes xml, %(<name>David</name>)
  end

  def test_one_level_camelize_true
    xml = { name: "David", street_name: "Paulina" }.to_xml(@xml_options.merge(camelize: true))
    assert_equal "<Person>", xml.first(8)
    assert_includes xml, %(<StreetName>Paulina</StreetName>)
    assert_includes xml, %(<Name>David</Name>)
  end

  def test_one_level_camelize_lower
    xml = { name: "David", street_name: "Paulina" }.to_xml(@xml_options.merge(camelize: :lower))
    assert_equal "<person>", xml.first(8)
    assert_includes xml, %(<streetName>Paulina</streetName>)
    assert_includes xml, %(<name>David</name>)
  end

  def test_one_level_with_types
    xml = { name: "David", street: "Paulina", age: 26, age_in_millis: 820497600000, moved_on: Date.new(2005, 11, 15), resident: :yes }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert_includes xml, %(<street>Paulina</street>)
    assert_includes xml, %(<name>David</name>)
    assert_includes xml, %(<age type="integer">26</age>)
    assert_includes xml, %(<age-in-millis type="integer">820497600000</age-in-millis>)
    assert_includes xml, %(<moved-on type="date">2005-11-15</moved-on>)
    assert_includes xml, %(<resident type="symbol">yes</resident>)
  end

  def test_one_level_with_nils
    xml = { name: "David", street: "Paulina", age: nil }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert_includes xml, %(<street>Paulina</street>)
    assert_includes xml, %(<name>David</name>)
    assert_includes xml, %(<age nil="true"/>)
  end

  def test_one_level_with_skipping_types
    xml = { name: "David", street: "Paulina", age: nil }.to_xml(@xml_options.merge(skip_types: true))
    assert_equal "<person>", xml.first(8)
    assert_includes xml, %(<street>Paulina</street>)
    assert_includes xml, %(<name>David</name>)
    assert_includes xml, %(<age nil="true"/>)
  end

  def test_one_level_with_yielding
    xml = { name: "David", street: "Paulina" }.to_xml(@xml_options) do |x|
      x.creator("Rails")
    end

    assert_equal "<person>", xml.first(8)
    assert_includes xml, %(<street>Paulina</street>)
    assert_includes xml, %(<name>David</name>)
    assert_includes xml, %(<creator>Rails</creator>)
  end

  def test_two_levels
    xml = { name: "David", address: { street: "Paulina" } }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert_includes xml, %(<address><street>Paulina</street></address>)
    assert_includes xml, %(<name>David</name>)
  end

  def test_two_levels_with_second_level_overriding_to_xml
    xml = { name: "David", address: { street: "Paulina" }, child: IWriteMyOwnXML.new }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert_includes xml, %(<address><street>Paulina</street></address>)
    assert_includes xml, %(<level_one><second_level>content</second_level></level_one>)
  end

  def test_two_levels_with_array
    xml = { name: "David", addresses: [{ street: "Paulina" }, { street: "Evergreen" }] }.to_xml(@xml_options)
    assert_equal "<person>", xml.first(8)
    assert_includes xml, %(<addresses type="array"><address>)
    assert_includes xml, %(<address><street>Paulina</street></address>)
    assert_includes xml, %(<address><street>Evergreen</street></address>)
    assert_includes xml, %(<name>David</name>)
  end

  def test_three_levels_with_array
    xml = { name: "David", addresses: [{ streets: [ { name: "Paulina" }, { name: "Paulina" } ] } ] }.to_xml(@xml_options)
    assert_includes xml, %(<addresses type="array"><address><streets type="array"><street><name>)
  end

  def test_timezoned_attributes
    xml = {
      created_at: Time.utc(1999, 2, 2),
      local_created_at: Time.utc(1999, 2, 2).in_time_zone("Eastern Time (US & Canada)")
    }.to_xml(@xml_options)
    assert_match %r{<created-at type="dateTime">1999-02-02T00:00:00Z</created-at>}, xml
    assert_match %r{<local-created-at type="dateTime">1999-02-01T19:00:00-05:00</local-created-at>}, xml
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
      expires_at: Time.utc(2007, 12, 25, 12, 34, 56),
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
    assert_predicate alert_at, :utc?
    assert_equal Time.utc(2008, 2, 10, 15, 30, 45), alert_at
  end

  def test_datetime_xml_type_with_non_utc_time
    alert_xml = <<-XML
      <alert>
        <alert_at type="datetime">2008-02-10T10:30:45-05:00</alert_at>
      </alert>
    XML
    alert_at = Hash.from_xml(alert_xml)["alert"]["alert_at"]
    assert_predicate alert_at, :utc?
    assert_equal Time.utc(2008, 2, 10, 15, 30, 45), alert_at
  end

  def test_datetime_xml_type_with_far_future_date
    alert_xml = <<-XML
      <alert>
        <alert_at type="datetime">2050-02-10T15:30:45Z</alert_at>
      </alert>
    XML
    alert_at = Hash.from_xml(alert_xml)["alert"]["alert_at"]
    assert_predicate alert_at, :utc?
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
