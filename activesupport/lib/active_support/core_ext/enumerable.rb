# frozen_string_literal: true

module Enumerable
  INDEX_WITH_DEFAULT = Object.new
  private_constant :INDEX_WITH_DEFAULT

  # Enumerable#sum was added in Ruby 2.4, but it only works with Numeric elements
  # when we omit an identity.

  # :stopdoc:

  # We can't use Refinements here because Refinements with Module which will be prepended
  # doesn't work well https://bugs.ruby-lang.org/issues/13446
  alias :_original_sum_with_required_identity :sum
  private :_original_sum_with_required_identity

  # :startdoc:

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
    if identity
      _original_sum_with_required_identity(identity, &block)
    elsif block_given?
      map(&block).sum(identity)
    else
      inject(:+) || 0
    end
  end

  # Convert an enumerable to a hash keying it by the block return value.
  #
  #   people.index_by(&:login)
  #   # => { "nextangle" => <Person ...>, "chade-" => <Person ...>, ...}
  #
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

  # Convert an enumerable to a hash keying it with the enumerable items and with the values returned in the block.
  #
  #   post = Post.new(title: "hey there", body: "what's up?")
  #
  #   %i( title body ).index_with { |attr_name| post.public_send(attr_name) }
  #   # => { title: "hey there", body: "what's up?" }
  def index_with(default = INDEX_WITH_DEFAULT)
    if block_given?
      result = {}
      each { |elem| result[elem] = yield(elem) }
      result
    elsif default != INDEX_WITH_DEFAULT
      result = {}
      each { |elem| result[elem] = default }
      result
    else
      to_enum(:index_with) { size if respond_to?(:size) }
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

  # Returns a new array that includes the passed elements.
  #
  #   [ 1, 2, 3 ].including(4, 5)
  #   # => [ 1, 2, 3, 4, 5 ]
  #
  #   ["David", "Rafael"].including %w[ Aaron Todd ]
  #   # => ["David", "Rafael", "Aaron", "Todd"]
  def including(*elements)
    to_a.including(*elements)
  end

  # The negative of the <tt>Enumerable#include?</tt>. Returns +true+ if the
  # collection does not include the object.
  def exclude?(object)
    !include?(object)
  end

  # Returns a copy of the enumerable excluding the specified elements.
  #
  #   ["David", "Rafael", "Aaron", "Todd"].excluding "Aaron", "Todd"
  #   # => ["David", "Rafael"]
  #
  #   ["David", "Rafael", "Aaron", "Todd"].excluding %w[ Aaron Todd ]
  #   # => ["David", "Rafael"]
  #
  #   {foo: 1, bar: 2, baz: 3}.excluding :bar
  #   # => {foo: 1, baz: 3}
  def excluding(*elements)
    elements.flatten!(1)
    reject { |element| elements.include?(element) }
  end

  # Alias for #excluding.
  def without(*elements)
    excluding(*elements)
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

# Using Refinements here in order not to expose our internal method
using Module.new {
  refine Array do
    alias :orig_sum :sum
  end
}

class Array #:nodoc:
  # Array#sum was added in Ruby 2.4 but it only works with Numeric elements.
  def sum(init = nil, &block)
    if init.is_a?(Numeric) || first.is_a?(Numeric)
      init ||= 0
      orig_sum(init, &block)
    else
      super
    end
  end
end
