class Array
  # Wraps the object in an Array unless it's an Array.  Converts the
  # object to an Array using #to_ary if it implements that.
  #
  # It differs with Array() in that it does not call +to_a+ on
  # the argument:
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
