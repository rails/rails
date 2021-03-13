# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/array"
require "active_support/core_ext/enumerable"

Payment = Struct.new(:price)
ExpandedPayment = Struct.new(:dollars, :cents)

class EnumerableTests < ActiveSupport::TestCase
  class GenericEnumerable
    include Enumerable

    def initialize(values = [1, 2, 3])
      @values = values
    end

    def each
      @values.each { |v| yield v }
    end
  end

  def assert_typed_equal(e, v, cls, msg = nil)
    assert_kind_of(cls, v, msg)
    assert_equal(e, v, msg)
  end

  def test_minimum
    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])
    assert_equal 5, payments.minimum(:price)
  end

  def test_minimum_with_empty_enumerable
    payments = GenericEnumerable.new([])
    assert_nil payments.minimum(:price)
  end

  def test_maximum
    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])
    assert_equal 15, payments.maximum(:price)
  end

  def test_maximum_with_empty_enumerable
    payments = GenericEnumerable.new([])
    assert_nil payments.maximum(:price)
  end

  def test_index_by
    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])
    assert_equal({ 5 => Payment.new(5), 15 => Payment.new(15), 10 => Payment.new(10) },
                 payments.index_by(&:price))
    assert_equal Enumerator, payments.index_by.class
    assert_nil payments.index_by.size
    assert_equal 42, (1..42).index_by.size
    assert_equal({ 5 => Payment.new(5), 15 => Payment.new(15), 10 => Payment.new(10) },
                 payments.index_by.each(&:price))
  end

  def test_index_with
    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])

    assert_equal({ Payment.new(5) => 5, Payment.new(15) => 15, Payment.new(10) => 10 }, payments.index_with(&:price))

    assert_equal({ title: nil, body: nil }, %i( title body ).index_with(nil))
    assert_equal({ title: [], body: [] }, %i( title body ).index_with([]))
    assert_equal({ title: {}, body: {} }, %i( title body ).index_with({}))

    assert_equal Enumerator, payments.index_with.class
    assert_nil payments.index_with.size
    assert_equal 42, (1..42).index_with.size
    assert_equal({ Payment.new(5) => 5, Payment.new(15) => 15, Payment.new(10) => 10 }, payments.index_with.each(&:price))
  end

  def test_many
    assert_equal false, GenericEnumerable.new([]).many?
    assert_equal false, GenericEnumerable.new([ 1 ]).many?
    assert_equal true,  GenericEnumerable.new([ 1, 2 ]).many?

    assert_equal false, GenericEnumerable.new([]).many? { |x| x > 1 }
    assert_equal false, GenericEnumerable.new([ 2 ]).many? { |x| x > 1 }
    assert_equal false, GenericEnumerable.new([ 1, 2 ]).many? { |x| x > 1 }
    assert_equal true,  GenericEnumerable.new([ 1, 2, 2 ]).many? { |x| x > 1 }
  end

  def test_many_iterates_only_on_what_is_needed
    infinity = 1.0 / 0.0
    very_long_enum = 0..infinity
    assert_equal true, very_long_enum.many?
    assert_equal true, very_long_enum.many? { |x| x > 100 }
  end

  def test_exclude?
    assert_equal true,  GenericEnumerable.new([ 1 ]).exclude?(2)
    assert_equal false, GenericEnumerable.new([ 1 ]).exclude?(1)
  end

  def test_excluding
    assert_equal [1, 2, 4], GenericEnumerable.new((1..5).to_a).excluding(3, 5)
    assert_equal [3, 4, 5], GenericEnumerable.new((1..5).to_a).excluding([1, 2])
    assert_equal [[0, 1]], GenericEnumerable.new([[0, 1], [1, 0]]).excluding([[1, 0]])
    assert_equal [1, 2, 4], (1..5).to_a.excluding(3, 5)
    assert_equal [1, 2, 4], (1..5).to_set.excluding(3, 5)
    assert_equal({ foo: 1, baz: 3 }, { foo: 1, bar: 2, baz: 3 }.excluding(:bar))
  end

  def test_without
    assert_equal [1, 2, 4], GenericEnumerable.new((1..5).to_a).without(3, 5)
    assert_equal [3, 4, 5], GenericEnumerable.new((1..5).to_a).without([1, 2])
  end

  def test_pluck
    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])
    assert_equal [5, 15, 10], payments.pluck(:price)

    payments = GenericEnumerable.new([
      ExpandedPayment.new(5, 99),
      ExpandedPayment.new(15, 0),
      ExpandedPayment.new(10, 50)
    ])
    assert_equal [[5, 99], [15, 0], [10, 50]], payments.pluck(:dollars, :cents)

    assert_equal [], [].pluck(:price)
    assert_equal [], [].pluck(:dollars, :cents)
  end

  def test_pick
    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])
    assert_equal 5, payments.pick(:price)

    payments = GenericEnumerable.new([
      ExpandedPayment.new(5, 99),
      ExpandedPayment.new(15, 0),
      ExpandedPayment.new(10, 50)
    ])
    assert_equal [5, 99], payments.pick(:dollars, :cents)

    assert_nil [].pick(:price)
    assert_nil [].pick(:dollars, :cents)
  end

  def test_compact_blank
    values = GenericEnumerable.new([1, "", nil, 2, " ", [], {}, false, true])

    assert_equal [1, 2, true], values.compact_blank
  end

  def test_array_compact_blank!
    values = [1, "", nil, 2, " ", [], {}, false, true]
    values.compact_blank!

    assert_equal [1, 2, true], values
  end

  def test_hash_compact_blank
    values = { a: "", b: 1, c: nil, d: [], e: false, f: true }
    assert_equal({ b: 1, f: true }, values.compact_blank)
  end

  def test_hash_compact_blank!
    values = { a: "", b: 1, c: nil, d: [], e: false, f: true }
    values.compact_blank!
    assert_equal({ b: 1, f: true }, values)
  end

  def test_in_order_of
    values = [ Payment.new(5), Payment.new(1), Payment.new(3) ]
    assert_equal [ Payment.new(1), Payment.new(5), Payment.new(3) ], values.in_order_of(:price, [ 1, 5, 3 ])
  end

  def test_in_order_of_ignores_missing_series
    values = [ Payment.new(5), Payment.new(1), Payment.new(3) ]
    assert_equal [ Payment.new(1), Payment.new(5), Payment.new(3) ], values.in_order_of(:price, [ 1, 2, 4, 5, 3 ])
  end

  def test_in_order_of_drops_elements_not_named_in_series
    values = [ Payment.new(5), Payment.new(1), Payment.new(3) ]
    assert_equal [ Payment.new(1), Payment.new(5) ], values.in_order_of(:price, [ 1, 5 ])
  end
end
