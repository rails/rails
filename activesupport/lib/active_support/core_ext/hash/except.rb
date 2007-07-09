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
          rejected = Set.new(respond_to?(:convert_key) ? keys.map { |key| convert_key(key) } : keys)
          reject { |key,| rejected.include?(key) }
        end

        # Replaces the hash without only the given keys.
        def except!(*keys)
          replace(except(*keys))
        end
      end
    end
  end
end
