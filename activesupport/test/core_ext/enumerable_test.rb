# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/array"
require "active_support/core_ext/enumerable"

Payment = Struct.new(:price)
ExpandedPayment = Struct.new(:dollars, :cents)

class SummablePayment < Payment
  def +(p) self.class.new(price + p.price) end
end

class EnumerableTests < ActiveSupport::TestCase
  class Money
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def +(other)
      Money.new(value + other.value)
    end

    def coerce(other)
      [Money.new(other), self]
    end

    def ==(other)
      other.value == value
    end
  end

  class GenericEnumerable
    include Enumerable

    def initialize(values = [1, 2, 3])
      @values = values
    end

    def each(&block)
      @values.each(&block)
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

  def test_sums
    enum = GenericEnumerable.new([5, 15, 10])
    assert_equal 30, enum.sum
    assert_equal 60, enum.sum { |i| i * 2 }

    enum = GenericEnumerable.new(%w(a b c))
    assert_equal "abc", enum.sum("")
    assert_equal "aabbcc", enum.sum("") { |i| i * 2 }
    assert_raises(TypeError) do
      enum.sum
    end
    assert_raises(TypeError) do
      enum.sum { |i| i * 2 }
    end

    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])
    assert_equal 30, payments.sum(&:price)
    assert_equal 60, payments.sum { |p| p.price * 2 }

    payments = GenericEnumerable.new([ SummablePayment.new(5), SummablePayment.new(15) ])
    assert_raises(TypeError) do
      payments.sum
    end
    assert_equal SummablePayment.new(20), payments.sum(SummablePayment.new(0))
    assert_equal SummablePayment.new(20), payments.sum(SummablePayment.new(0)) { |p| p }
    assert_raises(TypeError) do
      payments.sum { |p| p }
    end

    sum = GenericEnumerable.new([3, 5.quo(1)]).sum
    assert_typed_equal(8, sum, Rational)

    sum = GenericEnumerable.new([3, 5.quo(1)]).sum(0.0)
    assert_typed_equal(8.0, sum, Float)

    sum = GenericEnumerable.new([3, 5.quo(1), 7.0]).sum
    assert_typed_equal(15.0, sum, Float)

    sum = GenericEnumerable.new([3, 5.quo(1), Complex(7)]).sum
    assert_typed_equal(Complex(15), sum, Complex)
    assert_typed_equal(15, sum.real, Rational)
    assert_typed_equal(0, sum.imag, Integer)

    sum = GenericEnumerable.new([3.5, 5]).sum
    assert_typed_equal(8.5, sum, Float)

    sum = GenericEnumerable.new([2, 8.5]).sum
    assert_typed_equal(10.5, sum, Float)

    sum = GenericEnumerable.new([1.quo(2), 1]).sum
    assert_typed_equal(3.quo(2), sum, Rational)

    sum = GenericEnumerable.new([1.quo(2), 1.quo(3)]).sum
    assert_typed_equal(5.quo(6), sum, Rational)

    sum = GenericEnumerable.new([2.0, 3.0 * Complex::I]).sum
    assert_typed_equal(Complex(2.0, 3.0), sum, Complex)
    assert_typed_equal(2.0, sum.real, Float)
    assert_typed_equal(3.0, sum.imag, Float)

    sum = GenericEnumerable.new([1, 2]).sum(10) { |v| v * 2 }
    assert_typed_equal(16, sum, Integer)
  end

  def test_nil_sums
    expected_raise = TypeError

    assert_raise(expected_raise) { GenericEnumerable.new([5, 15, nil]).sum }
    assert_raises(expected_raise) do
      [nil].sum
    end

    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10), Payment.new(nil) ])
    assert_raise(expected_raise) { payments.sum(&:price) }

    assert_equal 60, payments.sum { |p| p.price.to_i * 2 }
  end

  def test_empty_sums
    assert_equal 0, GenericEnumerable.new([]).sum
    assert_equal [], GenericEnumerable.new([]).sum([])
    assert_equal 0, GenericEnumerable.new([]).sum { |i| i + 10 }
    assert_equal [], GenericEnumerable.new([]).sum([]) { |i| i + 10 }
    assert_equal Payment.new(0), GenericEnumerable.new([]).sum(Payment.new(0))
    assert_typed_equal 0.0, GenericEnumerable.new([]).sum(0.0), Float
  end

  def test_range_sums
    assert_equal 20, (1..4).sum { |i| i * 2 }
    assert_equal 10, (1..4).sum
    assert_equal 10, (1..4.5).sum
    assert_equal 6, (1...4).sum
    assert_raises(TypeError) do
      ("a".."c").sum
    end
    assert_equal "abc", ("a".."c").sum("")
    assert_equal 50_000_005_000_000, (0..10_000_000).sum
    assert_equal 0, (10..0).sum
    assert_equal 5, (10..0).sum(5)
    assert_equal 10, (10..10).sum
    assert_equal 42, (10...10).sum(42)
    assert_typed_equal 20.0, (1..4).sum(0.0) { |i| i * 2 }, Float
    assert_typed_equal 10.0, (1..4).sum(0.0), Float
    assert_typed_equal 20.0, (1..4).sum(10.0), Float
    assert_typed_equal 5.0, (10..0).sum(5.0), Float
  end

  def test_array_sums
    enum = [5, 15, 10]
    assert_equal 30, enum.sum
    assert_equal 60, enum.sum { |i| i * 2 }

    enum = %w(a b c)
    assert_raises(TypeError) do
      enum.sum
    end
    assert_equal "abc", enum.sum("")
    assert_raises(TypeError) do
      enum.sum { |i| i * 2 }
    end
    assert_equal "aabbcc", enum.sum("") { |i| i * 2 }

    payments = [ Payment.new(5), Payment.new(15), Payment.new(10) ]
    assert_equal 30, payments.sum(&:price)
    assert_equal 60, payments.sum { |p| p.price * 2 }

    payments = [ SummablePayment.new(5), SummablePayment.new(15) ]
    assert_raises(TypeError) do
      payments.sum
    end
    assert_equal SummablePayment.new(20), payments.sum(SummablePayment.new(0))
    assert_raises(TypeError) do
      payments.sum { |p| p }
    end
    assert_equal SummablePayment.new(20), payments.sum(SummablePayment.new(0)) { |p| p }

    assert_equal Money.new(3), [Money.new(1), Money.new(2)].sum

    sum = [3, 5.quo(1)].sum
    assert_typed_equal(8, sum, Rational)

    sum = [3, 5.quo(1)].sum(0.0)
    assert_typed_equal(8.0, sum, Float)

    sum = [3, 5.quo(1), 7.0].sum
    assert_typed_equal(15.0, sum, Float)

    sum = [3, 5.quo(1), Complex(7)].sum
    assert_typed_equal(Complex(15), sum, Complex)
    assert_typed_equal(15, sum.real, Rational)
    assert_typed_equal(0, sum.imag, Integer)

    sum = [3.5, 5].sum
    assert_typed_equal(8.5, sum, Float)

    sum = [2, 8.5].sum
    assert_typed_equal(10.5, sum, Float)

    sum = [1.quo(2), 1].sum
    assert_typed_equal(3.quo(2), sum, Rational)

    sum = [1.quo(2), 1.quo(3)].sum
    assert_typed_equal(5.quo(6), sum, Rational)

    sum = [2.0, 3.0 * Complex::I].sum
    assert_typed_equal(Complex(2.0, 3.0), sum, Complex)
    assert_typed_equal(2.0, sum.real, Float)
    assert_typed_equal(3.0, sum.imag, Float)

    sum = [1, 2].sum(10) { |v| v * 2 }
    assert_typed_equal(16, sum, Integer)
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
    assert_equal true,  GenericEnumerable.new([ 1, 2, 3]).each_with_index.many? { |x, i| x == i + 1 }
    assert_equal true,  GenericEnumerable.new([ [1, 2], [3, 4] ]).many? { |x| x.sum > 1 }
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

  def test_in_order_of_preserves_duplicates
    values = [ Payment.new(5), Payment.new(1), Payment.new(5) ]
    assert_equal [ Payment.new(1), Payment.new(5), Payment.new(5) ], values.in_order_of(:price, [ 1, 5 ])
  end

  def test_in_order_of_preserves_nested_elements
    values = [[:paid, { price: 1, currency: :eur }], [:opened, { price: 2, currency: :usd }]]
    assert_equal [[:opened, { price: 2, currency: :usd }], [:paid, { price: 1, currency: :eur }]], values.in_order_of(:first, [:opened, :paid])
  end

  def test_in_order_of_with_filter_false
    values = [ Payment.new(5), Payment.new(3), Payment.new(1) ]
    assert_equal [ Payment.new(1), Payment.new(5), Payment.new(3) ], values.in_order_of(:price, [ 1, 5 ], filter: false)
  end

  def test_sole
    expected_raise = Enumerable::SoleItemExpectedError

    assert_raise(expected_raise) { GenericEnumerable.new([]).sole }
    assert_equal 1, GenericEnumerable.new([1]).sole
    assert_raise(expected_raise) { GenericEnumerable.new([1, 2]).sole }
    assert_raise(expected_raise) { GenericEnumerable.new([1, nil]).sole }
  end

  def test_doesnt_bust_constant_cache
    skip "Only applies to MRI" unless defined?(RubyVM.stat)

    object = Object.new
    assert_no_difference -> { constant_cache_invalidations } do
      object.extend(Enumerable)
    end
  end

  private
    def constant_cache_invalidations
      RubyVM.stat(:constant_cache_invalidations)
    end
end
