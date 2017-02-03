module Enumerable
  # Calculates a sum from the elements.
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
  #  ['foo', 'bar'].sum # => "foobar"
  #  [[1, 2], [3, 1, 5]].sum # => [1, 2, 3, 1, 5]
  #
  # The default sum of an empty list is zero. You can override this default:
  #
  #  [].sum(Payment.new(0)) { |i| i.amount } # => Payment.new(0)
  def sum(identity = nil, &block)
    if block_given?
      map(&block).sum(identity)
    else
      sum = identity ? inject(identity, :+) : inject(:+)
      sum || identity || 0
    end
  end

  # Convert an enumerable to a hash.
  #
  #   people.index_by(&:login)
  #   # => { "nextangle" => <Person ...>, "chade-" => <Person ...>, ...}
  #   people.index_by { |person| "#{person.first_name} #{person.last_name}" }
  #   # => { "Chade- Fowlersburg-e" => <Person ...>, "David Heinemeier Hansson" => <Person ...>, ...}
  def index_by
    if block_given?
      result = {}
      each { |elem| result[yield(elem)] = elem }
      result
    else
      to_enum(:index_by) { size if respond_to?(:size) }
    end
  end

  # Returns +true+ if the enumerable has more than 1 element. Functionally
  # equivalent to <tt>enum.to_a.size > 1</tt>. Can be called with a block too,
  # much like any?, so <tt>people.many? { |p| p.age > 26 }</tt> returns +true+
  # if more than one person is over 26.
  def many?
    cnt = 0
    if block_given?
      any? do |element|
        cnt += 1 if yield element
        cnt > 1
      end
    else
      any? { (cnt += 1) > 1 }
    end
  end

  # The negative of the <tt>Enumerable#include?</tt>. Returns +true+ if the
  # collection does not include the object.
  def exclude?(object)
    !include?(object)
  end

  # Returns a copy of the enumerable without the specified elements.
  #
  #   ["David", "Rafael", "Aaron", "Todd"].without "Aaron", "Todd"
  #   # => ["David", "Rafael"]
  #
  #   {foo: 1, bar: 2, baz: 3}.without :bar
  #   # => {foo: 1, baz: 3}
  def without(*elements)
    reject { |element| elements.include?(element) }
  end

  # Convert an enumerable to an array based on the given key.
  #
  #   [{ name: "David" }, { name: "Rafael" }, { name: "Aaron" }].pluck(:name)
  #   # => ["David", "Rafael", "Aaron"]
  #
  #   [{ id: 1, name: "David" }, { id: 2, name: "Rafael" }].pluck(:id, :name)
  #   # => [[1, "David"], [2, "Rafael"]]
  def pluck(*keys)
    if keys.many?
      map { |element| keys.map { |key| element[key] } }
    else
      map { |element| element[keys.first] }
    end
  end
end

class Range #:nodoc:
  # Optimize range sum to use arithmetic progression if a block is not given and
  # we have a range of numeric values.
  def sum(identity = nil)
    if block_given? || !(first.is_a?(Integer) && last.is_a?(Integer))
      super
    else
      actual_last = exclude_end? ? (last - 1) : last
      if actual_last >= first
        sum = identity || 0
        sum + (actual_last - first + 1) * (actual_last + first) / 2
      else
        identity || 0
      end
    end
  end
end

# Array#sum was added in Ruby 2.4 but it only works with Numeric elements.
#
# We tried shimming it to attempt the fast native method, rescue TypeError,
# and fall back to the compatible implementation, but that's much slower than
# just calling the compat method in the first place.
if Array.instance_methods(false).include?(:sum) && !(%w[a].sum rescue false)
  # Using Refinements here in order not to expose our internal method
  using Module.new {
    refine Array do
      alias :orig_sum :sum
    end
  }

  class Array
    def sum(init = nil, &block) #:nodoc:
      if init.is_a?(Numeric) || first.is_a?(Numeric)
        init ||= 0
        orig_sum(init, &block)
      else
        super
      end
    end
  end
end
