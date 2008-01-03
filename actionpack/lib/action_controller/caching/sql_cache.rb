module ActionController #:nodoc:
  module Caching
    module SqlCache
      def self.included(base) #:nodoc:
        if defined?(ActiveRecord) && ActiveRecord::Base.respond_to?(:cache)
          base.alias_method_chain :perform_action, :caching
        end
      end

      protected
        def perform_action_with_caching
          ActiveRecord::Base.cache do
            perform_action_without_caching
          end
        end
    end
  end
end