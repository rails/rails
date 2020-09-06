# frozen_string_literal: true

require_relative '../../abstract_unit'
require 'active_support/core_ext/array'
require 'active_support/core_ext/hash'
require 'active_support/ordered_options'

class ExtractOptionsTest < ActiveSupport::TestCase
  class HashSubclass < Hash
  end

  class ExtractableHashSubclass < Hash
    def extractable_options?
      true
    end
  end

  def test_extract_options
    assert_equal({}, [].extract_options!)
    assert_equal({}, [1].extract_options!)
    assert_equal({ a: :b }, [{ a: :b }].extract_options!)
    assert_equal({ a: :b }, [1, { a: :b }].extract_options!)
  end

  def test_extract_options_doesnt_extract_hash_subclasses
    hash = HashSubclass.new
    hash[:foo] = 1
    array = [hash]
    options = array.extract_options!
    assert_equal({}, options)
    assert_equal([hash], array)
  end

  def test_extract_options_extracts_extractable_subclass
    hash = ExtractableHashSubclass.new
    hash[:foo] = 1
    array = [hash]
    options = array.extract_options!
    assert_equal({ foo: 1 }, options)
    assert_equal([], array)
  end

  def test_extract_options_extracts_hash_with_indifferent_access
    array = [{ foo: 1 }.with_indifferent_access]
    options = array.extract_options!
    assert_equal(1, options[:foo])
  end

  def test_extract_options_extracts_ordered_options
    hash = ActiveSupport::OrderedOptions.new
    hash.foo = 1
    array = [hash]
    options = array.extract_options!
    assert_equal({ foo: 1 }, options)
    assert_equal([], array)
  end
end
