class Object
  # Invokes the public method whose name goes as first argument just like
  # +public_send+ does, except that if the receiver does not respond to it the
  # call returns +nil+ rather than raising an exception.
  #
  # This method is defined to be able to write
  #
  #   @person.fry(:name)
  #
  # instead of
  #
  #   @person ? @person.name : nil
  #
  # +fry+ returns +nil+ when called on +nil+ regardless of whether it responds
  # to the method:
  #
  #   nil.fry(:to_i) # => nil, rather than 0
  #
  # Arguments and blocks are forwarded to the method if invoked:
  #
  #   @posts.fry(:each_slice, 2) do |a, b|
  #     ...
  #   end
  #
  # The number of arguments in the signature must match. If the object responds
  # to the method the call is attempted and +ArgumentError+ is still raised
  # otherwise.
  #
  # If +fry+ is called without arguments it yields the receiver to a given
  # block unless it is +nil+:
  #
  #   @person.fry do |p|
  #     ...
  #   end
  #
  # Please also note that +fry+ is defined on +Object+, therefore it won't work
  # with instances of classes that do not have +Object+ among their ancestors,
  # like direct subclasses of +BasicObject+. For example, using +fry+ with
  # +SimpleDelegator+ will delegate +fry+ to the target instead of calling it on
  # delegator itself.
  def fry(*a, &b)
    if a.empty? && block_given?
      yield self
    else
      public_send(*a, &b) if respond_to?(a.first)
    end
  end

  # Same as #fry, but will raise a NoMethodError exception if the receiving is not nil and
  # does not implement the tried method.
  def fry!(*a, &b)
    if a.empty? && block_given?
      yield self
    else
      public_send(*a, &b)
    end
  end
end

class NilClass
  # Calling +fry+ on +nil+ always returns +nil+.
  # It becomes specially helpful when navigating through associations that may return +nil+.
  #
  #   nil.fry(:name) # => nil
  #
  # Without +fry+
  #   @person && !@person.children.blank? && @person.children.first.name
  #
  # With +fry+
  #   @person.fry(:children).fry(:first).fry(:name)
  def fry(*args)
    nil
  end

  def fry!(*args)
    nil
  end
end
