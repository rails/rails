module ActiveSupport
  module Testing
    module GarbageCollection
      def self.included(base)
        base.teardown :scrub_leftover_instance_variables
      end

      private

      RESERVED_INSTANCE_VARIABLES = %w(@test_passed @passed @method_name @__name__ @_result).map(&:to_sym)

      def scrub_leftover_instance_variables
        (instance_variables.map(&:to_sym) - RESERVED_INSTANCE_VARIABLES).each do |var|
          remove_instance_variable(var)
        end
      end
    end
  end
end
