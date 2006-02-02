# Classes that include this module will automatically be reloaded
# by the Rails dispatcher when Dependencies.mechanism = :load.
module Reloadable
  class << self
    def included(base) #nodoc:
      if base.is_a?(Class) && ! base.respond_to?(:reloadable?)
        class << base
          define_method(:reloadable?) { true }
        end
      end
    end
    
    def reloadable_classes
      included_in_classes.select { |klass| klass.reloadable? }
    end
  end
end