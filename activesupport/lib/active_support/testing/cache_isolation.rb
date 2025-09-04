# frozen_string_literal: true

require "securerandom"

module ActiveSupport
  module Testing
    # Cache Isolation
    #
    # Automatically randomizes cache namespaces for each test to ensure proper
    # isolation. This prevents cache key collisions and removes the need for
    # explicit cache clearing in teardown.
    #
    # This module is automatically included in ActiveSupport::TestCase.
    module CacheIsolation
      def self.prepended(klass)
        klass.set_callback(:setup, :before, :isolate_cache_namespace)
      end

      private
        def isolate_cache_namespace
          return unless defined?(Rails) && Rails.respond_to?(:cache)

          store = Rails.cache
          return unless store.is_a?(ActiveSupport::Cache::Store)
          return unless store.respond_to?(:namespace=)

          original_namespace = store.namespace

          isolated_namespace = if original_namespace
            if original_namespace.include?("r:")
              "#{SecureRandom.hex(6)}r:" + original_namespace.split("r:", 2)[-1]
            else
              "#{SecureRandom.hex(6)}r:#{original_namespace}"
            end
          else
            "#{SecureRandom.hex(6)}r:"
          end

          store.namespace = isolated_namespace
        end
    end
  end
end
