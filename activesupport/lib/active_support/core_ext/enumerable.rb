require 'active_support/ordered_hash'

module Enumerable
  # Ruby 1.8.7 introduces group_by, but the result isn't ordered. Override it.
  remove_method(:group_by) if [].respond_to?(:group_by) && RUBY_VERSION < '1.9'

  # Collect an enumerable into sets, grouped by the result of a block. Useful,
  # for example, for grouping records by date.
  #
  # Example:
  #
  #   latest_transcripts.group_by(&:day).each do |day, transcripts|
  #     p "#{day} -> #{transcripts.map(&:class).join(', ')}"
  #   end
  #   "2006-03-01 -> Transcript"
  #   "2006-02-28 -> Transcript"
  #   "2006-02-27 -> Transcript, Transcript"
  #   "2006-02-26 -> Transcript, Transcript"
  #   "2006-02-25 -> Transcript"
  #   "2006-02-24 -> Transcript, Transcript"
  #   "2006-02-23 -> Transcript"
  def group_by
    assoc = ActiveSupport::OrderedHash.new

    each do |element|
      key = yield(element)

      if assoc.has_key?(key)
        assoc[key] << element
      else
        assoc[key] = [element]
      end
    end

    assoc
  end unless [].respond_to?(:group_by)

  # Calculates a sum from the elements. Examples:
  #
  #  payments.sum { |p| p.price * p.tax_rate }
  #  payments.sum(&:price)
  #
  # The latter is a shortcut for:
  #
  #  payments.inject(0) { |sum, p| sum + p.price }
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

  # Iterates over a collection, passing the current element *and* the
  # +memo+ to the block. Handy for building up hashes or
  # reducing collections down to one object. Examples:
  #
  #   %w(foo bar).each_with_object({}) { |str, hsh| hsh[str] = str.upcase }
  #   # => {'foo' => 'FOO', 'bar' => 'BAR'}
  #
  # *Note* that you can't use immutable objects like numbers, true or false as
  # the memo. You would think the following returns 120, but since the memo is
  # never changed, it does not.
  #
  #   (1..5).each_with_object(1) { |value, memo| memo *= value } # => 1
  #
  def each_with_object(memo, &block)
    each do |element|
      block.call(element, memo)
    end
    memo
  end unless [].respond_to?(:each_with_object)

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

class Range #:nodoc:
  # Optimize range sum to use arithmetic progression if a block is not given and
  # we have a range of numeric values.
  def sum(identity = 0)
    return super if block_given? || !(first.instance_of?(Integer) && last.instance_of?(Integer))
    actual_last = exclude_end? ? (last - 1) : last
    (actual_last - first + 1) * (actual_last + first) / 2
  end
end
