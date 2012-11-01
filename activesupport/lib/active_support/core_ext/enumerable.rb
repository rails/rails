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
  def index_by
    if block_given?
      Hash[map { |elem| [yield(elem), elem] }]
    else
      to_enum :index_by
    end
  end

  # Convert an enumerable to a hash, with the same block syntax as <tt>each_with_object</tt>.
  # Allows a default value or proc to be given. If <tt>set_default_on_lookup</tt> is <tt>true</tt>,
  # the default value will be converted to a proc that sets the Hash key when looked up.
  # This is ignored if default is already a proc.
  #
  # [1,3,5].each_with_hash {|i, h| h[i] = i ** 2 }
  #   => {1=>1, 3=>9, 5=>25}
  #
  # [3,4,5,4].each_with_hash(0) {|i, h| h[i] += i }
  #   => {3=>3, 4=>8, 5=>5}
  #
  # ['red', 'blue'].each_with_hash(-> h, k { h[k] = k.upcase }) {|c, h| h[c] << '!' }
  #   => {'red'=>'RED!', 'blue'=>'BLUE!'}
  #
  # [1,2,3,2,1].each_with_hash([], true) {|i, h| h[i] << i * 2 }
  #   => {1=>[2, 2], 2=>[4, 4], 3=>[3]}
  def each_with_hash(default = nil, set_default_on_lookup = false)
    if block_given?
      hash = if Proc === default
        Hash.new &default
      else
        if set_default_on_lookup
          Hash.new &-> hash, key { hash[key] = default.dup }
        else
          Hash.new default
        end
      end
      self.each { |el| yield el, hash }
      hash
    else
      to_enum :each_with_hash, default, set_default_on_lookup
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
