# frozen_string_literal: true

module ActiveRecord
  class Migration
    class CompatibilityBehavior # :nodoc:
      module Resolver # :nodoc:
        # Schema loads resolve like migrations: a versioned
        # ActiveRecord::Schema[x.y] maps to V<x_y>, and ActiveRecord::Schema
        # itself maps to Current. A behavior whose version matches therefore
        # also runs during db:schema:load; check for
        # ActiveRecord::Schema::Definition inside the behavior when schema
        # loads must keep the adapter's default behavior.
        def for(migration_class) # :nodoc:
          version_class = Compatibility.version_for(migration_class)
          return CompatibilityBehavior unless version_class
          # version_pairs is oldest-first; a behavior covers its own version and older.
          # Pick the lowest defined version >= the migration's, else the no-op base.
          pair = version_pairs.find { |version, _| version_class <= version }
          pair ? pair.last : CompatibilityBehavior
        end

        private
          def version_pairs
            @version_pairs ||= constants.grep(/\AV\d+_\d+\z/)
              .map { |name| [Compatibility.const_get(name, false), const_get(name)] }
              .sort { |a, b| a.first <=> b.first }
          end
      end

      def initialize(migration)
        @migration = migration
      end

      # Consumed by adapter behaviors; the connection does not know this key.
      def create_table(*args, **options)
        options.delete(:_compat_injected_default)
        super
      end

      private
        attr_reader :migration

        # `super` from a subclass's operation method lands here and executes
        # the operation, so behaviors adjust arguments before `super` and run
        # follow-up work after it.
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
