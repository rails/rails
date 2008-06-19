require 'set'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      # Return a hash that includes everything but the given keys. This is useful for
      # limiting a set of parameters to everything but a few known toggles:
      #
      #   @person.update_attributes(params[:person].except(:admin))
      module Except
        # Returns a new hash without the given keys.
        def except(*keys)
          clone.except!(*keys)
        end

        # Replaces the hash without only the given keys.
        def except!(*keys)
          keys.map! { |key| convert_key(key) } if respond_to?(:convert_key)
          keys.each { |key| delete(key) }
          self
        end
      end
    end
  end
end
