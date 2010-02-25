require 'active_support/deprecation'

class Object
  # Get object's meta (ghost, eigenclass, singleton) class.
  #
  # Deprecated in favor of Object#singleton_class.
  def metaclass
    class << self
      self
    end
  end

  deprecate :metaclass => :singleton_class
end
