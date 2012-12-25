require 'abstract_unit'
require 'active_support/core_ext/array'
require 'active_support/core_ext/enumerable'

Payment = Struct.new(:price)
class SummablePayment < Payment
  def +(p) self.class.new(price + p.price) end
end

class EnumerableTests < ActiveSupport::TestCase
  Enumerator = [].each.class

  class GenericEnumerable
    include Enumerable
    def initialize(values = [1, 2, 3])
      @values = values
    end

    def each
      @values.each{|v| yield v}
    end
  end

  def test_group_by
    names = %w(marcel sam david jeremy)
    klass = Struct.new(:name)
    objects = (1..50).inject([]) do |people,|
      p = klass.new
      p.name = names.sort_by { rand }.first
      people << p
    end

    enum = GenericEnumerable.new(objects)
    grouped = enum.group_by { |object| object.name }

    grouped.each do |name, group|
      assert group.all? { |person| person.name == name }
    end

    assert_equal objects.uniq.map(&:name), grouped.keys
    assert({}.merge(grouped), "Could not convert ActiveSupport::OrderedHash into Hash")
    assert_equal Enumerator, enum.group_by.class
    assert_equal grouped, enum.group_by.each(&:name)
  end

  def test_sums
    enum = GenericEnumerable.new([5, 15, 10])
    assert_equal 30, enum.sum
    assert_equal 60, enum.sum { |i| i * 2}

    enum = GenericEnumerable.new(%w(a b c))
    assert_equal 'abc', enum.sum
    assert_equal 'aabbcc', enum.sum { |i| i * 2 }

    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])
    assert_equal 30, payments.sum(&:price)
    assert_equal 60, payments.sum { |p| p.price * 2 }

    payments = GenericEnumerable.new([ SummablePayment.new(5), SummablePayment.new(15) ])
    assert_equal SummablePayment.new(20), payments.sum
    assert_equal SummablePayment.new(20), payments.sum { |p| p }
  end

  def test_nil_sums
    expected_raise = TypeError

    assert_raise(expected_raise) { GenericEnumerable.new([5, 15, nil]).sum }

    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10), Payment.new(nil) ])
    assert_raise(expected_raise) { payments.sum(&:price) }

    assert_equal 60, payments.sum { |p| p.price.to_i * 2 }
  end

  def test_empty_sums
    assert_equal 0, GenericEnumerable.new([]).sum
    assert_equal 0, GenericEnumerable.new([]).sum { |i| i + 10 }
    assert_equal Payment.new(0), GenericEnumerable.new([]).sum(Payment.new(0))
  end

  def test_range_sums
    assert_equal 20, (1..4).sum { |i| i * 2 }
    assert_equal 10, (1..4).sum
    assert_equal 10, (1..4.5).sum
    assert_equal 6, (1...4).sum
    assert_equal 'abc', ('a'..'c').sum
    assert_equal 50_000_005_000_000, (0..10_000_000).sum
    assert_equal 0, (10..0).sum
    assert_equal 5, (10..0).sum(5)
    assert_equal 10, (10..10).sum
    assert_equal 42, (10...10).sum(42)
  end

  def test_index_by
    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])
    assert_equal({ 5 => Payment.new(5), 15 => Payment.new(15), 10 => Payment.new(10) },
                 payments.index_by { |p| p.price })
    assert_equal Enumerator, payments.index_by.class
    assert_equal({ 5 => Payment.new(5), 15 => Payment.new(15), 10 => Payment.new(10) },
                 payments.index_by.each { |p| p.price })
  end

  def test_many
    assert_equal false, GenericEnumerable.new([]         ).many?
    assert_equal false, GenericEnumerable.new([ 1 ]      ).many?
    assert_equal true,  GenericEnumerable.new([ 1, 2 ]   ).many?

    assert_equal false, GenericEnumerable.new([]         ).many? {|x| x > 1 }
    assert_equal false, GenericEnumerable.new([ 2 ]      ).many? {|x| x > 1 }
    assert_equal false, GenericEnumerable.new([ 1, 2 ]   ).many? {|x| x > 1 }
    assert_equal true,  GenericEnumerable.new([ 1, 2, 2 ]).many? {|x| x > 1 }
  end

  def test_many_iterates_only_on_what_is_needed
    infinity = 1.0/0.0
    very_long_enum = 0..infinity
    assert_equal true, very_long_enum.many?
    assert_equal true, very_long_enum.many?{|x| x > 100}
  end

  def test_exclude?
    assert_equal true,  GenericEnumerable.new([ 1 ]).exclude?(2)
    assert_equal false, GenericEnumerable.new([ 1 ]).exclude?(1)
  end
end
