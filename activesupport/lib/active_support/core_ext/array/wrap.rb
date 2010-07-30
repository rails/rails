class Array
  # <tt>Array.wrap</tt> is like <tt>Kernel#Array</tt> except:
  #
  # * If the argument responds to +to_ary+ the method is invoked. <tt>Kernel#Array</tt>
  # moves on to try +to_a+ if the returned value is +nil+, but <tt>Arraw.wrap</tt> returns
  # such a +nil+ right away.
  # * If the returned value from +to_ary+ is neither +nil+ nor an +Array+ object, <tt>Kernel#Array</tt>
  # raises an exception, while <tt>Array.wrap</tt> does not, it just returns the value.
  # * It does not call +to_a+ on the argument, though special-cases +nil+ to return an empty array.
  #
  # The last point is particularly worth comparing for some enumerables:
  #
  #   Array(:foo => :bar)      # => [[:foo, :bar]]
  #   Array.wrap(:foo => :bar) # => [{:foo => :bar}]
  #
  #   Array("foo\nbar")        # => ["foo\n", "bar"], in Ruby 1.8
  #   Array.wrap("foo\nbar")   # => ["foo\nbar"]
  def self.wrap(object)
    if object.nil?
      []
    elsif object.respond_to?(:to_ary)
      object.to_ary
    else
      [object]
    end
  end
end
