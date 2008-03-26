class Class #:nodoc:
  
  # Will unassociate the class with its subclasses as well as uninitializing the subclasses themselves.
  # >> Integer.remove_subclasses
  # => [Bignum, Fixnum]
  # >> Fixnum
  # NameError: uninitialized constant Fixnum
  def remove_subclasses
    Object.remove_subclasses_of(self)
  end

  # Returns a list of classes that inherit from this class in an array.
  # Example: Integer.subclasses => ["Bignum", "Fixnum"]
  def subclasses
    Object.subclasses_of(self).map { |o| o.to_s }
  end

  # Allows you to remove individual subclasses or a selection of subclasses from a class without removing all of them.
  def remove_class(*klasses)
    klasses.flatten.each do |klass|
      # Skip this class if there is nothing bound to this name
      next unless defined?(klass.name)
      
      basename = klass.to_s.split("::").last
      parent = klass.parent
      
      # Skip this class if it does not match the current one bound to this name
      next unless parent.const_defined?(basename) && klass = parent.const_get(basename)

      parent.instance_eval { remove_const basename } unless parent == klass
    end
  end
end
