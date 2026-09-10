# frozen_string_literal: true

# :markup: markdown

require "active_record/connection_adapters/ractor_connection_proxy"

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionProxy < AbstractAdapter # :nodoc:
      # Worker-Ractor stand-in for Mysql2Adapter and TrilogyAdapter connections,
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
      class MySQLProxy < RactorConnectionProxy
        def disable_referential_integrity
          old = query_value("SELECT @@FOREIGN_KEY_CHECKS")

          begin
            update("SET FOREIGN_KEY_CHECKS = 0")
            yield
          ensure
            update("SET FOREIGN_KEY_CHECKS = #{old}") if active?
          end
        end

        # CAPABILITIES ============================================

        def supports_advisory_locks?
          pure_remote_dispatch(:supports_advisory_locks?)
        end

        def supports_bulk_alter?
          pure_remote_dispatch(:supports_bulk_alter?)
        end

        def supports_check_constraints?
          pure_remote_dispatch(:supports_check_constraints?)
        end

        def supports_comments?
          pure_remote_dispatch(:supports_comments?)
        end

        def supports_comments_in_create?
          pure_remote_dispatch(:supports_comments_in_create?)
        end

        def supports_common_table_expressions?
          pure_remote_dispatch(:supports_common_table_expressions?)
        end

        def supports_datetime_with_precision?
          pure_remote_dispatch(:supports_datetime_with_precision?)
        end

        def supports_disabling_indexes?
          pure_remote_dispatch(:supports_disabling_indexes?)
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

        def supports_indexes_in_create?
          pure_remote_dispatch(:supports_indexes_in_create?)
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

        def supports_optimizer_hints?
          pure_remote_dispatch(:supports_optimizer_hints?)
        end

        def supports_restart_db_transaction?
          pure_remote_dispatch(:supports_restart_db_transaction?)
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

        def cast_bound_value(...)
          pure_remote_dispatch(:cast_bound_value, ...)
        end

        def quoted_binary(...)
          pure_remote_dispatch(:quoted_binary, ...)
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

        # Compiles and executes worker-side like any other query; only the
        # capability-dependent clause is resolved remotely.
        def explain(arel_or_sql, binds = [], options = [])
          sql, binds = to_sql_and_binds(arel_or_sql, binds)
          sql = pure_remote_dispatch(:build_explain_clause, options) + " " + sql
          start   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result  = select_all(sql, "EXPLAIN", binds)
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

          MySQL::ExplainPrettyPrinter.new.pp(result, elapsed)
        end

        def high_precision_current_timestamp
          remote_dispatch(:high_precision_current_timestamp)
        end

        def write_query?(...)
          remote_dispatch(:write_query?, ...)
        end

        # SCHEMA STATEMENTS =======================================

        def add_index_options(...)
          remote_dispatch(:add_index_options, ...)
        end

        def create_index_definition(...)
          remote_dispatch(:create_index_definition, ...)
        end

        # Built locally against the proxy: the dumper only drives the
        # dispatchable connection interface and must not cross itself.
        def create_schema_dumper(options)
          MySQL::SchemaDumper.create(self, options)
        end

        def create_table(...)
          remote_dispatch(:create_table, ...)
        end

        def indexes(...)
          remote_dispatch(:indexes, ...)
        end

        def internal_string_options_for_primary_key
          remote_dispatch(:internal_string_options_for_primary_key)
        end

        def remove_foreign_key(...)
          remote_dispatch(:remove_foreign_key, ...)
        end

        def table_alias_length
          remote_dispatch(:table_alias_length)
        end

        def type_to_sql(...)
          pure_remote_dispatch(:type_to_sql, ...)
        end

        def update_table_definition(...)
          remote_dispatch(:update_table_definition, ...)
        end

        # ADAPTER SPECIFIC ========================================

        def add_index(...)
          remote_dispatch(:add_index, ...)
        end

        def build_create_index_definition(...)
          remote_dispatch(:build_create_index_definition, ...)
        end

        def case_sensitive_comparison(...)
          pure_remote_dispatch(:case_sensitive_comparison, ...)
        end

        def change_column(...)
          remote_dispatch(:change_column, ...)
        end

        def change_column_comment(...)
          remote_dispatch(:change_column_comment, ...)
        end

        def change_column_default(...)
          remote_dispatch(:change_column_default, ...)
        end

        def change_column_null(...)
          remote_dispatch(:change_column_null, ...)
        end

        def change_table_comment(...)
          remote_dispatch(:change_table_comment, ...)
        end

        def check_constraints(...)
          remote_dispatch(:check_constraints, ...)
        end

        def columns_for_distinct(...)
          remote_dispatch(:columns_for_distinct, ...)
        end

        def default_index_type?(...)
          remote_dispatch(:default_index_type?, ...)
        end

        def disable_index(...)
          remote_dispatch(:disable_index, ...)
        end

        def drop_table(...)
          remote_dispatch(:drop_table, ...)
        end

        def empty_all_tables
          remote_dispatch(:empty_all_tables)
        end

        def empty_insert_statement_value(...)
          remote_dispatch(:empty_insert_statement_value, ...)
        end

        def enable_index(...)
          remote_dispatch(:enable_index, ...)
        end

        def foreign_keys(...)
          remote_dispatch(:foreign_keys, ...)
        end

        def get_advisory_lock(...)
          remote_dispatch(:get_advisory_lock, ...)
        end

        def get_database_version
          remote_dispatch(:get_database_version)
        end

        def index_algorithms
          remote_dispatch(:index_algorithms)
        end

        def quote_string(...)
          pure_remote_dispatch(:quote_string, ...)
        end

        def release_advisory_lock(...)
          remote_dispatch(:release_advisory_lock, ...)
        end

        def remove_index(...)
          remote_dispatch(:remove_index, ...)
        end

        def rename_column(...)
          remote_dispatch(:rename_column, ...)
        end

        def rename_index(...)
          remote_dispatch(:rename_index, ...)
        end

        def rename_table(...)
          remote_dispatch(:rename_table, ...)
        end

        def return_value_after_insert?(...)
          remote_dispatch(:return_value_after_insert?, ...)
        end

        def savepoint_errors_invalidate_transactions?
          remote_dispatch(:savepoint_errors_invalidate_transactions?)
        end

        def table_comment(...)
          remote_dispatch(:table_comment, ...)
        end

        private
          # DATABASE STATEMENTS =====================================

          def combine_multi_statements(...)
            remote_dispatch(:combine_multi_statements, ...)
          end

          # SCHEMA STATEMENTS =======================================

          def add_options_for_index_columns(...)
            remote_dispatch(:add_options_for_index_columns, ...)
          end

          def create_alter_table(...)
            remote_dispatch(:create_alter_table, ...)
          end

          def data_source_sql(...)
            remote_dispatch(:data_source_sql, ...)
          end

          def extract_foreign_key_action(...)
            remote_dispatch(:extract_foreign_key_action, ...)
          end

          def fetch_type_metadata(...)
            remote_dispatch(:fetch_type_metadata, ...)
          end

          def quoted_scope(...)
            pure_remote_dispatch(:quoted_scope, ...)
          end

          def valid_index_options
            remote_dispatch(:valid_index_options)
          end

          def valid_primary_key_options
            remote_dispatch(:valid_primary_key_options)
          end

          # ADAPTER SPECIFIC ========================================

          def can_perform_case_insensitive_comparison_for?(...)
            pure_remote_dispatch(:can_perform_case_insensitive_comparison_for?, ...)
          end

          def drop_table_sql(...)
            remote_dispatch(:drop_table_sql, ...)
          end

          def fetch_column_definitions(...)
            remote_dispatch(:fetch_column_definitions, ...)
          end

          def fetch_table_options(...)
            remote_dispatch(:fetch_table_options, ...)
          end

          def warning_ignored?(...)
            remote_dispatch(:warning_ignored?, ...)
          end
      end
    end
  end
end
