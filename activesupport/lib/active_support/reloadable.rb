require 'active_support/deprecation'

# A deprecated mechanism to mark a class reloadable.
# 
# Deprecated as of Rails 1.2.
# All autoloaded objects are now unloaded.
module Reloadable
  class << self
    
    def included(base) #nodoc:
      unless base.ancestors.include?(Reloadable::Subclasses) # Avoid double warning
        ActiveSupport::Deprecation.warn "Reloadable has been deprecated and has no effect.", caller
      end
      
      raise TypeError, "Only Classes can be Reloadable!" unless base.is_a? Class
      
      unless base.respond_to?(:reloadable?)
        class << base
          define_method(:reloadable?) do
            ActiveSupport::Deprecation.warn "Reloadable has been deprecated and reloadable? has no effect", caller
            true
          end
        end
      end
    end
    
    def reloadable_classes
      ActiveSupport::Deprecation.silence do
        included_in_classes.select { |klass| klass.reloadable? }
      end
    end
    deprecate :reloadable_classes
  end
  
  # Captures the common pattern where a base class should not be reloaded,
  # but its subclasses should be.
  # 
  # Deprecated as of Rails 1.2.
  # All autoloaded objects are now unloaded.
  module Subclasses
    def self.included(base) #nodoc:
      base.send :include, Reloadable
      ActiveSupport::Deprecation.warn "Reloadable::Subclasses has been deprecated and has no effect.", caller
      (class << base; self; end).send(:define_method, :reloadable?) do
        ActiveSupport::Deprecation.warn "Reloadable has been deprecated and reloadable? has no effect", caller
        base != self
      end
    end
  end
  
  module Deprecated
    
    def self.included(base)
      class << base
        define_method(:reloadable?) do
          ActiveSupport::Deprecation.warn "Reloadable has been deprecated and reloadable? has no effect", caller
          true # This might not have the desired effect, as AR::B.reloadable? => true.
        end
      end
    end
    
  end
  
end