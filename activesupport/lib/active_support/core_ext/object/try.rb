class Object
  # Invokes the public method identified by the symbol +method+, passing it any arguments
  # and/or the block specified, just like the regular Ruby <tt>Object#public_send</tt> does.
  #
  # *Unlike* that method however, a +NoMethodError+ exception will *not* be raised
  # and +nil+ will be returned instead, if the receiving object is a +nil+ object or NilClass.
  #
  # This is also true if the receiving object does not implemented the tried method. It will
  # return +nil+ in that case as well.
  #
  # If try is called without a method to call, it will yield any given block with the object.
  #
  # Please also note that +try+ is defined on +Object+, therefore it won't work with
  # subclasses of +BasicObject+. For example, using try with +SimpleDelegator+ will
  # delegate +try+ to target instead of calling it on delegator itself.
  #
  # Without +try+
  #   @person && @person.name
  # or
  #   @person ? @person.name : nil
  #
  # With +try+
  #   @person.try(:name)
  #
  # +try+ also accepts arguments and/or a block, for the method it is trying
  #   Person.try(:find, 1)
  #   @people.try(:collect) {|p| p.name}
  #
  # Without a method argument try will yield to the block unless the receiver is nil.
  #   @person.try { |p| "#{p.first_name} #{p.last_name}" }
  #
  # +try+ behaves like +Object#public_send+, unless called on +NilClass+.
  def try(*a, &b)
    if a.empty? && block_given?
      yield self
    else
      public_send(*a, &b) if respond_to?(a.first)
    end
  end

  # Same as #try, but will raise a NoMethodError exception if the receiving is not nil and
  # does not implemented the tried method.
  def try!(*a, &b)
    if a.empty? && block_given?
      yield self
    else
      public_send(*a, &b)
    end
  end
end

class NilClass
  # Calling +try+ on +nil+ always returns +nil+.
  # It becomes specially helpful when navigating through associations that may return +nil+.
  #
  #   nil.try(:name) # => nil
  #
  # Without +try+
  #   @person && !@person.children.blank? && @person.children.first.name
  #
  # With +try+
  #   @person.try(:children).try(:first).try(:name)
  def try(*args)
    nil
  end

  def try!(*args)
    nil
  end
end
