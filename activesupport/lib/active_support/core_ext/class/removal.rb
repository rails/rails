require 'active_support/core_ext/object/extending'
require 'active_support/core_ext/module/introspection'

class Class #:nodoc:
  
  # Unassociates the class with its subclasses and removes the subclasses
  # themselves.
  #
  #   Integer.remove_subclasses # => [Bignum, Fixnum]
  #   Fixnum                    # => NameError: uninitialized constant Fixnum
  def remove_subclasses
    Object.remove_subclasses_of(self)
  end

  # Returns an array with the names of the subclasses of +self+ as strings.
  #
  #   Integer.subclasses # => ["Bignum", "Fixnum"]
  def subclasses
    Object.subclasses_of(self).map { |o| o.to_s }
  end

  # Removes the classes in +klasses+ from their parent module.
  #
  # Ordinary classes belong to some module via a constant. This method computes
  # that constant name from the class name and removes it from the module it
  # belongs to.
  #
  #   Object.remove_class(Integer) # => [Integer]
  #   Integer                      # => NameError: uninitialized constant Integer
  #
  # Take into account that in general the class object could be still stored
  # somewhere else.
  #
  #   i = Integer                  # => Integer
  #   Object.remove_class(Integer) # => [Integer]
  #   Integer                      # => NameError: uninitialized constant Integer
  #   i.subclasses                 # => ["Bignum", "Fixnum"]
  #   Fixnum.superclass            # => Integer
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
