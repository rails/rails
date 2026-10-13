# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  class Migration
    class CompatibilityBehavior # :nodoc:
      module Resolver # :nodoc:
        def for(migration_class)
          version_pairs.find { |version, _| migration_class <= version }&.last || CompatibilityBehavior
        end

        private
          def version_pairs
            @version_pairs ||= constants.grep(/\AV\d+_\d+\z/)
              .map { |name| [Compatibility.const_get(name, false), const_get(name)] }
              .sort_by(&:first)
          end
      end

      def initialize(migration)
        @migration = migration
      end

      private
        attr_reader :migration

        def method_missing(method, ...)
          migration.execute_operation(method, ...)
        end

        def respond_to_missing?(method, include_private = false)
          migration.execution_strategy.respond_to?(method, include_private) || super
        end

        def connection
          migration.connection
        end
    end
  end
end
