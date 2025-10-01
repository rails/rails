# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/array"

class DuplicatesTest < ActiveSupport::TestCase
  def test_integers
    ary = [1, 2, 3]
    assert_equal false, ary.duplicates?
  end

  def test_integers_duplicates
    ary = [1, 2, 3, 1]
    assert_equal true, ary.duplicates?
  end

  def test_strings
    ary = %w(foo bar)
    assert_equal false, ary.duplicates?
  end

  def test_strings_duplicates
    ary = %w(foo bar foo foo)
    assert_equal true, ary.duplicates?
  end

  def test_symbols
    ary = [:foo, :bar]
    assert_equal false, ary.duplicates?
  end

  def test_symbols_duplicates
    ary = [:foo, :bar, :foo, :bar]
    assert_equal true, ary.duplicates?
  end

  def test_empty
    assert_equal false, [].duplicates?
  end

  def test_nil
    ary = [nil, nil]
    assert_equal true, ary.duplicates?
  end

  def test_single_element
    ary = [42]
    assert_equal false, ary.duplicates?
  end
end
