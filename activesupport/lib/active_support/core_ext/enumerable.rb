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

  # Convert an enumerable to a hash.
  #
  #   people.index_by(&:login)
  #     => { "nextangle" => <Person ...>, "chade-" => <Person ...>, ...}
  #   people.index_by { |person| "#{person.first_name} #{person.last_name}" }
  #     => { "Chade- Fowlersburg-e" => <Person ...>, "David Heinemeier Hansson" => <Person ...>, ...}
  #
  def index_by
    if block_given?
      Hash[map { |elem| [yield(elem), elem] }]
    else
      to_enum :index_by
    end
  end

  # Returns true if the enumerable has more than 1 element. Functionally equivalent to enum.to_a.size > 1.
  # Can be called with a block too, much like any?, so <tt>people.many? { |p| p.age > 26 }</tt> returns true if more than one person is over 26.
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

  # The negative of the <tt>Enumerable#include?</tt>. Returns true if the collection does not include the object.
  def exclude?(object)
    !include?(object)
  end


  # Remove nil and blank objects
  #
  # Example
  #
  #   Arrays
  #   [1, 2, nil, "", 3, [4, 5, nil]].clean
  #   # => [1, 2, 3, [4, 5]]
  #
  #   Hashes
  #   Hash[:one => 1, :two => nil, :three => 3, :four => { :a => 'a', :b => '' }].clean
  #   # => {:one => 1, :three => 3, :four => { :a => 'a' } }
  #
  #   Mixed Hashes and Arrays
  #   [Hash[:one => nil, :two => 2], true].clean
  #   # => [{:two => 2}, true]
  def clean
    dup.clean!
  end

  def clean!
    reject! do |item|
      obj = is_a?(Hash) ? self[item] : item

      if obj.respond_to?(:reject!)
        obj.clean!
        obj.blank?
      else
        obj.blank? && !obj.is_a?(FalseClass)
      end
    end
    self
  end
end

class Range #:nodoc:
  # Optimize range sum to use arithmetic progression if a block is not given and
  # we have a range of numeric values.
  def sum(identity = 0)
    if block_given? || !(first.is_a?(Integer) && last.is_a?(Integer))
      super
    else
      actual_last = exclude_end? ? (last - 1) : last
      if actual_last >= first
        (actual_last - first + 1) * (actual_last + first) / 2
      else
        identity
      end
    end
  end
end
