require 'abstract_unit'
require 'active_support/core_ext/array'
require 'active_support/core_ext/enumerable'

Payment = Struct.new(:price)
ExpandedPayment = Struct.new(:dollars, :cents)

class SummablePayment < Payment
  def +(p) self.class.new(price + p.price) end
end

class EnumerableTests < ActiveSupport::TestCase

  class GenericEnumerable
    include Enumerable
    def initialize(values = [1, 2, 3])
      @values = values
    end

    def each
      @values.each{|v| yield v}
    end

    def count
      @values.count
    end

    def length
      @values.length
    end
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

  def test_mult
    expected_raise = RuntimeError

    enum = GenericEnumerable.new([5, 15, 10])
    assert_equal 750, enum.mult
    assert_equal 6000, enum.mult { |i| i * 2}

    enum = GenericEnumerable.new(%w(a b c))
    assert_raise(expected_raise) { enum.mult }
    assert_raise(expected_raise) { enum.mult { |i| i * 2 } }

    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])
    assert_equal 750, payments.mult(&:price)
    assert_equal 6000, payments.mult { |p| p.price * 2 }
  end 

  def test_nil_mult
    assert_equal nil, GenericEnumerable.new([5, 15, nil]).mult

    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10), Payment.new(nil) ])
    assert_equal nil, payments.mult(&:price)

    assert_equal 0, payments.mult { |p| p.price.to_i * 2 }
  end  

  def test_empty_mult
    assert_nil GenericEnumerable.new([]).each.mult
    assert_nil GenericEnumerable.new([]).each.mult { |i| i + 10 }
    assert_nil GenericEnumerable.new([]).each.mult(Payment.new(0))
  end 

  def test_range_mult
    expected_raise = RuntimeError

    assert_equal 384, (1..4).mult { |i| i * 2 }
    assert_equal 24, (1..4).mult
    assert_equal 24, (1..4.5).mult
    assert_equal 6, (1...4).mult
    assert_raise(expected_raise) { ('a'..'c').mult }
    assert_equal 1220136825991110068701238785423046926253574342803192842192413588385845373153881997605496447502203281863013616477148203584163378722078177200480785205159329285477907571939330603772960859086270429174547882424912726344305670173270769461062802310452644218878789465754777149863494367781037644274033827365397471386477878495438489595537537990423241061271326984327745715546309977202781014561081188373709531016356324432987029563896628911658974769572087926928871281780070265174507768410719624390394322536422605234945850129918571501248706961568141625359056693423813008856249246891564126775654481886506593847951775360894005745238940335798476363944905313062323749066445048824665075946735862074637925184200459369692981022263971952597190945217823331756934581508552332820762820023402626907898342451712006207714640979456116127629145951237229913340169552363850942885592018727433795173014586357570828355780158735432768888680120399882384702151467605445407663535984174430480128938313896881639487469658817504506926365338175055478128640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, (1..500).mult
    assert_equal 0, (0..10_000).mult
    assert_equal 1, (10..1).mult
    assert_equal 5, (10..1).mult(5)
    assert_equal 10, (10..10).mult
    assert_equal 42, (10...10).mult(42)
  end   

  def test_avgs
    expected_raise = RuntimeError

    enum = GenericEnumerable.new([5, 15, 10])
    assert_equal 10.0, enum.avg
    assert_equal 20.0, enum.avg { |i| i * 2}

    enum = GenericEnumerable.new(%w(a b c))
    assert_raise(expected_raise) { enum.avg }
    assert_raise(expected_raise) { enum.avg { |i| i * 2 } }

    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])
    assert_equal 10.0, payments.avg(&:price)
    assert_equal 20.0, payments.avg { |p| p.price * 2 }
  end 

  def test_medians
    expected_raise = RuntimeError

    enum = GenericEnumerable.new([5, 15, 10, 200, 70])
    assert_equal 15.0, enum.median
    assert_equal 30.0, enum.median { |i| i * 2}

    enum = GenericEnumerable.new(%w(a b c))
    assert_raise(expected_raise) { enum.median }
    assert_raise(expected_raise) { enum.median { |i| i * 2 } }

    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10), Payment.new(200), Payment.new(70)])
    assert_equal 15.0, payments.median(&:price)
    assert_equal 30.0, payments.median { |p| p.price * 2 }
  end    

  def test_index_by
    payments = GenericEnumerable.new([ Payment.new(5), Payment.new(15), Payment.new(10) ])
    assert_equal({ 5 => Payment.new(5), 15 => Payment.new(15), 10 => Payment.new(10) },
                 payments.index_by(&:price))
    assert_equal Enumerator, payments.index_by.class
    if Enumerator.method_defined? :size
      assert_equal nil, payments.index_by.size
      assert_equal 42, (1..42).index_by.size
    end
    assert_equal({ 5 => Payment.new(5), 15 => Payment.new(15), 10 => Payment.new(10) },
                 payments.index_by.each(&:price))
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

  def test_without
    assert_equal [1, 2, 4], GenericEnumerable.new((1..5).to_a).without(3, 5)
    assert_equal [1, 2, 4], (1..5).to_a.without(3, 5)
    assert_equal [1, 2, 4], (1..5).to_set.without(3, 5)
    assert_equal({foo: 1, baz: 3}, {foo: 1, bar: 2, baz: 3}.without(:bar))
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
  end
end
