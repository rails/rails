# frozen_string_literal: true

# :markup: markdown

require "active_record/connection_adapters/ractor_connection_proxy"

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionProxy < AbstractAdapter # :nodoc:
      # Worker-Ractor stand-in for SQLite3Adapter connections,
      # hand-defining the adapter methods it must dispatch to the
      # token-pinned main-Ractor connection: everything the adapter
      # overrides or adds on top of AbstractAdapter, minus the worker-local
      # query pipeline (execute, select_all, ...), exception translation, and
      # physical-connection machinery, which the proxy implements itself.
      #
      # `remote_dispatch` first materializes lazily begun worker-side
      # transactions so a rollback covers the remote work;
      # `pure_remote_dispatch` is for methods that never touch the database
      # (quoting, typing, feature flags) and must not materialize them.
      # Zero-arity `supports_*` flags are answered from the connection
      # profile's capability snapshot without a main-Ractor round trip.
      #
      # `disable_referential_integrity` wraps a caller block that must run on
      # the worker, so it cannot be dispatched remotely; it is defined below
      # to run locally through the query pipeline instead.
      class SQLite3Proxy < RactorConnectionProxy
        def disable_referential_integrity
          old_foreign_keys = query_value("PRAGMA foreign_keys", nil)
          old_defer_foreign_keys = query_value("PRAGMA defer_foreign_keys", nil)

          begin
            execute("PRAGMA defer_foreign_keys = ON")
            execute("PRAGMA foreign_keys = OFF")
            yield
          ensure
            execute("PRAGMA defer_foreign_keys = #{old_defer_foreign_keys}")
            execute("PRAGMA foreign_keys = #{old_foreign_keys}")
          end
        end

        # CAPABILITIES ============================================

        def supports_check_constraints?
          pure_remote_dispatch(:supports_check_constraints?)
        end

        def supports_common_table_expressions?
          pure_remote_dispatch(:supports_common_table_expressions?)
        end

        def supports_concurrent_connections?
          pure_remote_dispatch(:supports_concurrent_connections?)
        end

        def supports_datetime_with_precision?
          pure_remote_dispatch(:supports_datetime_with_precision?)
        end

        def supports_ddl_transactions?
          pure_remote_dispatch(:supports_ddl_transactions?)
        end

        def supports_deferrable_constraints?
          pure_remote_dispatch(:supports_deferrable_constraints?)
        end

        def supports_explain?
          pure_remote_dispatch(:supports_explain?)
        end

        def supports_expression_index?
          pure_remote_dispatch(:supports_expression_index?)
        end

        def supports_foreign_keys?
          pure_remote_dispatch(:supports_foreign_keys?)
        end

        def supports_index_sort_order?
          pure_remote_dispatch(:supports_index_sort_order?)
        end

        def supports_insert_conflict_target?
          pure_remote_dispatch(:supports_insert_conflict_target?)
        end

        def supports_insert_on_duplicate_skip?
          pure_remote_dispatch(:supports_insert_on_duplicate_skip?)
        end

        def supports_insert_on_duplicate_update?
          pure_remote_dispatch(:supports_insert_on_duplicate_update?)
        end

        def supports_insert_returning?
          pure_remote_dispatch(:supports_insert_returning?)
        end

        def supports_json?
          pure_remote_dispatch(:supports_json?)
        end

        def supports_lazy_transactions?
          pure_remote_dispatch(:supports_lazy_transactions?)
        end

        def supports_partial_index?
          pure_remote_dispatch(:supports_partial_index?)
        end

        def supports_savepoints?
          pure_remote_dispatch(:supports_savepoints?)
        end

        def supports_transaction_isolation?
          pure_remote_dispatch(:supports_transaction_isolation?)
        end

        def supports_views?
          pure_remote_dispatch(:supports_views?)
        end

        def supports_virtual_columns?
          pure_remote_dispatch(:supports_virtual_columns?)
        end

        # QUOTING =================================================

        def quote(...)
          pure_remote_dispatch(:quote, ...)
        end

        def quote_default_expression(...)
          pure_remote_dispatch(:quote_default_expression, ...)
        end

        def quote_string(...)
          pure_remote_dispatch(:quote_string, ...)
        end

        def quote_table_name_for_assignment(...)
          pure_remote_dispatch(:quote_table_name_for_assignment, ...)
        end

        def quoted_binary(...)
          pure_remote_dispatch(:quoted_binary, ...)
        end

        def quoted_time(...)
          pure_remote_dispatch(:quoted_time, ...)
        end

        def type_cast(...)
          remote_dispatch(:type_cast, ...)
        end

        def unquoted_false
          remote_dispatch(:unquoted_false)
        end

        def unquoted_true
          remote_dispatch(:unquoted_true)
        end

        # DATABASE STATEMENTS =====================================

        def default_insert_value(...)
          remote_dispatch(:default_insert_value, ...)
        end

        def explain(...)
          remote_dispatch(:explain, ...)
        end

        def high_precision_current_timestamp
          remote_dispatch(:high_precision_current_timestamp)
        end

        def reset_isolation_level
          remote_dispatch(:reset_isolation_level)
        end

        def write_query?(...)
          remote_dispatch(:write_query?, ...)
        end

        # SCHEMA STATEMENTS =======================================

        def add_check_constraint(...)
          remote_dispatch(:add_check_constraint, ...)
        end

        def add_foreign_key(...)
          remote_dispatch(:add_foreign_key, ...)
        end

        def check_constraints(...)
          remote_dispatch(:check_constraints, ...)
        end

        def create_schema_dumper(...)
          remote_dispatch(:create_schema_dumper, ...)
        end

        def indexes(...)
          remote_dispatch(:indexes, ...)
        end

        def remove_check_constraint(...)
          remote_dispatch(:remove_check_constraint, ...)
        end

        def remove_foreign_key(...)
          remote_dispatch(:remove_foreign_key, ...)
        end

        # ADAPTER SPECIFIC ========================================

        def add_belongs_to(...)
          remote_dispatch(:add_belongs_to, ...)
        end

        def add_column(...)
          remote_dispatch(:add_column, ...)
        end

        def add_reference(...)
          remote_dispatch(:add_reference, ...)
        end

        def add_timestamps(...)
          remote_dispatch(:add_timestamps, ...)
        end

        def build_insert_sql(...)
          remote_dispatch(:build_insert_sql, ...)
        end

        def change_column(...)
          remote_dispatch(:change_column, ...)
        end

        def change_column_default(...)
          remote_dispatch(:change_column_default, ...)
        end

        def change_column_null(...)
          remote_dispatch(:change_column_null, ...)
        end

        def check_all_foreign_keys_valid!
          remote_dispatch(:check_all_foreign_keys_valid!)
        end

        def create_virtual_table(...)
          remote_dispatch(:create_virtual_table, ...)
        end

        def database_exists?
          remote_dispatch(:database_exists?)
        end

        def drop_virtual_table(...)
          remote_dispatch(:drop_virtual_table, ...)
        end

        def foreign_keys(...)
          remote_dispatch(:foreign_keys, ...)
        end

        def get_database_version
          remote_dispatch(:get_database_version)
        end

        def remove_column(...)
          remote_dispatch(:remove_column, ...)
        end

        def remove_columns(...)
          remote_dispatch(:remove_columns, ...)
        end

        def remove_index(...)
          remote_dispatch(:remove_index, ...)
        end

        def rename_column(...)
          remote_dispatch(:rename_column, ...)
        end

        def rename_table(...)
          remote_dispatch(:rename_table, ...)
        end

        def requires_reloading?
          remote_dispatch(:requires_reloading?)
        end

        private
          # DATABASE STATEMENTS =====================================

          def build_truncate_statement(...)
            remote_dispatch(:build_truncate_statement, ...)
          end

          # SCHEMA STATEMENTS =======================================

          def data_source_sql(...)
            remote_dispatch(:data_source_sql, ...)
          end

          def quoted_scope(...)
            pure_remote_dispatch(:quoted_scope, ...)
          end

          def valid_table_definition_options
            remote_dispatch(:valid_table_definition_options)
          end

          def validate_index_length!(...)
            remote_dispatch(:validate_index_length!, ...)
          end

          # ADAPTER SPECIFIC ========================================

          def bind_params_length
            remote_dispatch(:bind_params_length)
          end

          def fetch_column_definitions(...)
            remote_dispatch(:fetch_column_definitions, ...)
          end
      end
    end
  end
end
