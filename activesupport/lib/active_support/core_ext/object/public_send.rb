require 'active_support/core_ext/kernel/singleton_class'

class Object
  unless Object.public_method_defined?(:public_send)
    # Backports Object#public_send from 1.9
    def public_send(method, *args, &block)
      # Don't create a singleton class for the object if it doesn't already have one
      # (This also protects us from classes like Fixnum and Symbol, which cannot have a
      # singleton class.)
      klass = singleton_methods.any? ? self.singleton_class : self.class

      if klass.public_method_defined?(method)
        send(method, *args, &block)
      else
        if klass.private_method_defined?(method)
          raise NoMethodError, "private method `#{method}' called for #{inspect}"
        elsif klass.protected_method_defined?(method)
          raise NoMethodError, "protected method `#{method}' called for #{inspect}"
        else
          raise NoMethodError, "undefined method `#{method}' for #{inspect}"
        end
      end
    end
  end
end
