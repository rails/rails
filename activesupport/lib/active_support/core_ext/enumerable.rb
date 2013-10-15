require 'active_support/ordered_hash'

module Enumerable
  # Calculates a sum from the elements. Examples:
  #
  #  payments.sum { |p| p.price * p.tax_rate }
  #  payments.sum(&:price)
  #
  # The latter is a shortcut for:
  #
  #  payments.inject { |sum, p| sum + p.price }
  #
  # It can also calculate the sum without the use of a block.
  #
  #  [5, 15, 10].sum # => 30
  #  ["foo", "bar"].sum # => "foobar"
  #  [[1, 2], [3, 1, 5]].sum => [1, 2, 3, 1, 5]
  #
  # The default sum of an empty list is zero. You can override this default:
  #
  #  [].sum(Payment.new(0)) { |i| i.amount } # => Payment.new(0)
  #
  def sum(identity = 0, &block)
    if block_given?
      map(&block).sum(identity)
    else
      inject { |sum, element| sum + element } || identity
    end
  end

  # Convert an enumerable to a hash. Examples:
  #
  #   people.index_by(&:login)
  #     => { "nextangle" => <Person ...>, "chade-" => <Person ...>, ...}
  #   people.index_by { |person| "#{person.first_name} #{person.last_name}" }
  #     => { "Chade- Fowlersburg-e" => <Person ...>, "David Heinemeier Hansson" => <Person ...>, ...}
  # 
  def index_by
    inject({}) do |accum, elem|
      accum[yield(elem)] = elem
      accum
    end
  end
  
  # Returns true if the collection has more than 1 element. Functionally equivalent to collection.size > 1.
  # Works with a block too ala any?, so people.many? { |p| p.age > 26 } # => returns true if more than 1 person is over 26.
  def many?(&block)
    size = block_given? ? select(&block).size : self.size
    size > 1
  end

  
  # The negative of the Enumerable#include?. Returns true if the collection does not include the object.
  def exclude?(object)
    !include?(object)
  end
end
