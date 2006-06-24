require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/symbol'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/enumerable'

Payment = Struct.new(:price)

class EnumerableTests < Test::Unit::TestCase
  def test_group_by
    names = %w(marcel sam david jeremy)
    klass = Class.new
    klass.send(:attr_accessor, :name)
    objects = (1..50).inject([]) do |people,| 
      p = klass.new
      p.name = names.sort_by { rand }.first
      people << p
    end

    objects.group_by {|object| object.name}.each do |name, group|
      assert group.all? {|person| person.name == name}
    end
  end
  
  def test_sums
    payments = [ Payment.new(5), Payment.new(15), Payment.new(10) ]
    assert_equal 30, payments.sum(&:price)
    assert_equal 60, payments.sum { |p| p.price * 2 }
  end
  
  def test_index_by
    payments = [ Payment.new(5), Payment.new(15), Payment.new(10) ]
    assert_equal(
      {5 => payments[0], 15 => payments[1], 10 => payments[2]},
      payments.index_by(&:price)
    )
  end
  
end
