# frozen_string_literal: true

module ActiveRecord
  class Migration
    # = Execution Strategy
    #
    # ExecutionStrategy is the base class for migration execution strategies.
    # A migration execution strategy handles method calls made by migrations
    # that the migration class does not implement directly.
    #
    # When a migration calls methods like +create_table+, +add_column+, or
    # +add_index+, these calls are delegated to the execution strategy, which
    # determines how they should be executed.
    #
    # == Customizing Migration Execution
    #
    # You can create custom execution strategies by subclassing ExecutionStrategy
    # (or more commonly, ActiveRecord::Migration::DefaultStrategy) and overriding
    # methods to customize migration behavior. For example:
    #
    #   class MyCustomStrategy < ActiveRecord::Migration::DefaultStrategy
    #     def create_table(table_name, **options)
    #       # Custom logic before creating a table
    #       puts "Creating table: #{table_name}"
    #       super
    #     end
    #
    #     def drop_table(table_name, **options)
    #       # Custom logic for dropping tables
    #       super
    #     end
    #   end
    #
    #   # Apply globally
    #   config.active_record.migration_strategy = MyCustomStrategy
    #
    #   # Or apply to a specific adapter
    #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.migration_strategy = MyCustomStrategy
    #
    # The strategy receives the current migration instance when initialized,
    # accessible via the +migration+ attribute.
    class ExecutionStrategy
      def initialize(migration)
        @migration = migration
      end

      private
        attr_reader :migration
    end
  end
end
