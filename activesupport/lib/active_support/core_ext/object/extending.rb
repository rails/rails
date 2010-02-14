require 'active_support/core_ext/class/subclasses'

class Object
  # Exclude this class unless it's a subclass of our supers and is defined.
  # We check defined? in case we find a removed class that has yet to be
  # garbage collected. This also fails for anonymous classes -- please
  # submit a patch if you have a workaround.
  def subclasses_of(*superclasses) #:nodoc:
    Class.subclasses_of(*superclasses)
  end
end
