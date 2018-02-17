# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/array"

class GroupingTest < ActiveSupport::TestCase
  def test_in_groups_of_with_perfect_fit
    groups = []
    ("a".."i").to_a.in_groups_of(3) do |group|
      groups << group
    end

    assert_equal [%w(a b c), %w(d e f), %w(g h i)], groups
    assert_equal [%w(a b c), %w(d e f), %w(g h i)], ("a".."i").to_a.in_groups_of(3)
  end

  def test_in_groups_of_with_padding
    groups = []
    ("a".."g").to_a.in_groups_of(3) do |group|
      groups << group
    end

    assert_equal [%w(a b c), %w(d e f), ["g", nil, nil]], groups
  end

  def test_in_groups_of_pads_with_specified_values
    groups = []

    ("a".."g").to_a.in_groups_of(3, "foo") do |group|
      groups << group
    end

    assert_equal [%w(a b c), %w(d e f), %w(g foo foo)], groups
  end

  def test_in_groups_of_without_padding
    groups = []

    ("a".."g").to_a.in_groups_of(3, false) do |group|
      groups << group
    end

    assert_equal [%w(a b c), %w(d e f), %w(g)], groups
  end

  def test_in_groups_returned_array_size
    array = (1..7).to_a

    1.upto(array.size + 1) do |number|
      assert_equal number, array.in_groups(number).size
    end
  end

  def test_in_groups_with_empty_array
    assert_equal [[], [], []], [].in_groups(3)
  end

  def test_in_groups_with_block
    array = (1..9).to_a
    groups = []

    array.in_groups(3) do |group|
      groups << group
    end

    assert_equal array.in_groups(3), groups
  end

  def test_in_groups_with_perfect_fit
    assert_equal [[1, 2, 3], [4, 5, 6], [7, 8, 9]],
      (1..9).to_a.in_groups(3)
  end

  def test_in_groups_with_padding
    array = (1..7).to_a

    assert_equal [[1, 2, 3], [4, 5, nil], [6, 7, nil]],
      array.in_groups(3)
    assert_equal [[1, 2, 3], [4, 5, "foo"], [6, 7, "foo"]],
      array.in_groups(3, "foo")
  end

  def test_in_groups_without_padding
    assert_equal [[1, 2, 3], [4, 5], [6, 7]],
      (1..7).to_a.in_groups(3, false)
  end

  def test_in_groups_invalid_argument
    assert_raises(ArgumentError) { [].in_groups_of(0) }
    assert_raises(ArgumentError) { [].in_groups_of(-1) }
    assert_raises(ArgumentError) { [].in_groups_of(nil) }
  end
end

class SplitTest < ActiveSupport::TestCase
  def test_split_with_empty_array
    assert_equal [[]], [].split(0)
  end

  def test_split_with_argument
    a = [1, 2, 3, 4, 5]
    assert_equal [[1, 2], [4, 5]],  a.split(3)
    assert_equal [[1, 2, 3, 4, 5]], a.split(0)
    assert_equal [1, 2, 3, 4, 5], a
  end

  def test_split_with_block
    a = (1..10).to_a
    assert_equal [[1, 2], [4, 5], [7, 8], [10]], a.split { |i| i % 3 == 0 }
    assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], a
  end

  def test_split_with_edge_values
    a = [1, 2, 3, 4, 5]
    assert_equal [[], [2, 3, 4, 5]],  a.split(1)
    assert_equal [[1, 2, 3, 4], []],  a.split(5)
    assert_equal [[], [2, 3, 4], []], a.split { |i| i == 1 || i == 5 }
    assert_equal [1, 2, 3, 4, 5], a
  end

  def test_split_with_repeated_values
    a = [1, 2, 3, 5, 5, 3, 4, 6, 2, 1, 3]
    assert_equal [[1, 2], [5, 5], [4, 6, 2, 1], []], a.split(3)
    assert_equal [[1, 2, 3], [], [3, 4, 6, 2, 1, 3]], a.split(5)
    assert_equal [[1, 2], [], [], [], [4, 6, 2, 1], []], a.split { |i| i == 3 || i == 5 }
    assert_equal [1, 2, 3, 5, 5, 3, 4, 6, 2, 1, 3], a
  end
end
