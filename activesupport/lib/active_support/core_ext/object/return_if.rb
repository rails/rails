class Object
  # Invokes the predicate method identified by the symbol or string +method+, passing it any arguments
  # and/or the block specified, just like the Rails <tt>Object#try</tt> does, but returning the receiver
  # if the predicate is evaluated to +true+ or +nil+ if it is +false+.
  #
  # Similar to the <tt>Object#try</tt> method, a +NoMethodError+ exception will *not* be raised
  # and +nil+ will be returned instead, if the receiving object is a +nil+ object or NilClass.
  #
  # If return_if is called without a method to call, it will yield any given block with the object.
  #
  # ==== Examples
  #
  # Array.return_if(:is_a?, Class) # => Array
  # 'flask'.return_if(:is_a?, Class) # => nil
  #
  # ('a'..'z').return_if(:any?) { |c| c == 'n' } # => ('a'..'z')
  # @user.return_if(:active?).return_if(:verified?)
  #
  #
  # Without +return_if+
  #   if @person && @person.valid?
  #     @person
  #   else
  #     nil
  #   end
  #
  # or using +try+ is better
  #
  #   @person.try(:valid?) && @person
  #
  #
  # With +return_if+
  #   @person.return_if(:valid?)
  #
  # +return_if+ accepts arguments and/or a block for the method it is trying
  #   @person.return_if(:forehead_size_is?, :massive)
  #   @people.return_if(:all?) {|p| p.awesome?}
  #
  # +return_if+ also accepts a string of method names sepearted by a dot '.' if you
  # want to return the parent object based on a predicate of an association
  #   @person.return_if('friends.empty?') # :(
  #
  # Without a method argument +return_if+ will yield to the block unless the receiver is nil.
  #   @user.return_if { |u| u.activated? || u.too_cool_for_activation? }
  def return_if(*args, &block)
    unless args.empty?
      methods     = args.first.to_s.split('.')
      params      = args[1..-1]
      last_method = methods.pop

      result = methods.inject(self) do |acc, method_name|
        acc.try(method_name)
      end

      return return_if { result.try(last_method, *params, &block) }
    end

    (yield(self) || nil) && self
  end
end

class NilClass
  # Calling +return_if+ on +nil+ always returns +nil+.
  # It becomes specially helpful when combining predicates that may return +false+, and thus +return_if+ would return +nil+.
  #
  # === Examples
  #
  #   nil.return_if(:valid?) # => nil
  #   nil.return_if('children.include?', joe) # => nil
  #
  # Without +return_if+
  #   if @person && @person.valid?
  #     @person
  #   else
  #     nil
  #   end
  #
  # Slightly better with +try+
  #   @person.try(:valid?) && @person
  #
  # With +return_if+
  #   @person.return_if(:valid?)
  #
  def return_if(*args, &block)
    nil
  end
end
