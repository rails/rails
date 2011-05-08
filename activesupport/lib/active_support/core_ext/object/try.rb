class Object
  # Invokes the method identified by the symbol +method+, passing it any arguments
  # and/or the block specified, just like the regular Ruby <tt>Object#send</tt> does.
  #
  # *Unlike* that method however, a +NoMethodError+ exception will *not* be raised
  # and +nil+ will be returned instead, if the receiving object is a +nil+ object or NilClass.
  #
  # If try is called without a method to call, it will yield any given block with the object.
  #
  # ==== Examples
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
  #--
  # +try+ behaves like +Object#send+, unless called on +NilClass+.
  def try(*a, &b)
    if a.empty? && block_given?
      yield self
    else
      __send__(*a, &b)
    end
  end
end

class NilClass
  # Calling +try+ on +nil+ always returns +nil+.
  # It becomes specially helpful when navigating through associations that may return +nil+.
  #
  # === Examples
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
end
