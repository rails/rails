class Object
  # Invokes the public method whose name goes as first argument just like
  # +public_send+ does, except that if the receiver does not respond to it the
  # call returns +nil+ rather than raising an exception.
  #
  # This method is defined to be able to write
  #
  #   @person.do_or_do_not(:name)
  #
  # instead of
  #
  #   @person ? @person.name : nil
  #
  # +do_or_do_not+ returns +nil+ when called on +nil+ regardless of whether it responds
  # to the method:
  #
  #   nil.do_or_do_not(:to_i) # => nil, rather than 0
  #
  # Arguments and blocks are forwarded to the method if invoked:
  #
  #   @posts.do_or_do_not(:each_slice, 2) do |a, b|
  #     ...
  #   end
  #
  # The number of arguments in the signature must match. If the object responds
  # to the method the call is attempted and +ArgumentError+ is still raised
  # otherwise.
  #
  # If +do_or_do_not+ is called without arguments it yields the receiver to a given
  # block unless it is +nil+:
  #
  #   @person.do_or_do_not do |p|
  #     ...
  #   end
  #
  # Please also note that +do_or_do_not+ is defined on +Object+, therefore it won't work
  # with instances of classes that do not have +Object+ among their ancestors,
  # like direct subclasses of +BasicObject+. For example, using +do_or_do_not+ with
  # +SimpleDelegator+ will delegate +do_or_do_not+ to the target instead of calling it on
  # delegator itself.
  def do_or_do_not(*a, &b)
    if a.empty? && block_given?
      yield self
    else
      public_send(*a, &b) if respond_to?(a.first)
    end
  end

  # Same as #do_or_do_not, but will raise a NoMethodError exception if the receiving is not nil and
  # does not implement the tried method.
  def do_or_do_not!(*a, &b)
    if a.empty? && block_given?
      yield self
    else
      public_send(*a, &b)
    end
  end
end

class NilClass
  # Calling +do_or_do_not+ on +nil+ always returns +nil+.
  # It becomes specially helpful when navigating through associations that may return +nil+.
  #
  #   nil.do_or_do_not(:name) # => nil
  #
  # Without +do_or_do_not+
  #   @person && !@person.children.blank? && @person.children.first.name
  #
  # With +do_or_do_not+
  #   @person.do_or_do_not(:children).do_or_do_not(:first).do_or_do_not(:name)
  def do_or_do_not(*args)
    nil
  end

  def do_or_do_not!(*args)
    nil
  end
end
