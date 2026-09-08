# frozen_string_literal: true

module ActiveRecord
  class Migration
    # = Default Strategy
    #
    # DefaultStrategy is the default execution strategy for migrations.
    # It delegates all method calls directly to the connection adapter,
    # which is the standard behavior for executing migration commands.
    #
    # This class is the recommended base class for custom migration strategies.
    # By inheriting from DefaultStrategy, you can override specific methods
    # while retaining the default behavior for all other migration operations.
    #
    # == Example: Creating a Custom Strategy
    #
    #   class AuditingStrategy < ActiveRecord::Migration::DefaultStrategy
    #     def create_table(table_name, **options)
    #       Rails.logger.info "Creating table: #{table_name}"
    #       super
    #     end
    #
    #     def drop_table(table_name, **options)
    #       Rails.logger.warn "Dropping table: #{table_name}"
    #       super
    #     end
    #   end
    #
    #   # Apply globally
    #   config.active_record.migration_strategy = AuditingStrategy
    #
    #   # Or apply to a specific adapter
    #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.migration_strategy = AuditingStrategy
    #
    # == Available Methods
    #
    # DefaultStrategy responds to all methods available on the connection adapter,
    # including but not limited to:
    #
    # * +create_table+
    # * +drop_table+
    # * +add_column+
    # * +remove_column+
    # * +add_index+
    # * +remove_index+
    # * +add_foreign_key+
    # * +remove_foreign_key+
    # * +execute+
    #
    # See ActiveRecord::ConnectionAdapters::SchemaStatements for the complete
    # list of available schema modification methods.
    class DefaultStrategy < ExecutionStrategy
      private
        def method_missing(method, ...)
          connection.send(method, ...)
        end

        def respond_to_missing?(method, include_private = false)
          connection.respond_to?(method, include_private) || super
        end

        def connection
          migration.connection
        end
    end
  end
end
