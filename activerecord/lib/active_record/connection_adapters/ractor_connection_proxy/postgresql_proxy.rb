# frozen_string_literal: true

# :markup: markdown

require "active_record/connection_adapters/ractor_connection_proxy"
require "active_record/connection_adapters/postgresql/referential_integrity"

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionProxy < AbstractAdapter # :nodoc:
      # Worker-Ractor stand-in for PostgreSQLAdapter connections,
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
      # `disable_referential_integrity` and `check_all_foreign_keys_valid!`
      # wrap or drive caller-visible work that must run on the worker, so
      # they cannot be dispatched remotely; the included ReferentialIntegrity
      # module runs them locally through the query pipeline instead.
      class PostgreSQLProxy < RactorConnectionProxy
        include PostgreSQL::ReferentialIntegrity

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

        def supports_common_table_expressions?
          pure_remote_dispatch(:supports_common_table_expressions?)
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

        def supports_enforced_foreign_keys?
          pure_remote_dispatch(:supports_enforced_foreign_keys?)
        end

        def supports_exclusion_constraints?
          pure_remote_dispatch(:supports_exclusion_constraints?)
        end

        def supports_explain?
          pure_remote_dispatch(:supports_explain?)
        end

        def supports_expression_index?
          pure_remote_dispatch(:supports_expression_index?)
        end

        def supports_extensions?
          pure_remote_dispatch(:supports_extensions?)
        end

        def supports_foreign_keys?
          pure_remote_dispatch(:supports_foreign_keys?)
        end

        def supports_foreign_tables?
          pure_remote_dispatch(:supports_foreign_tables?)
        end

        def supports_index_include?
          pure_remote_dispatch(:supports_index_include?)
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

        def supports_materialized_views?
          pure_remote_dispatch(:supports_materialized_views?)
        end

        def supports_nulls_not_distinct?
          pure_remote_dispatch(:supports_nulls_not_distinct?)
        end

        def supports_optimizer_hints?
          pure_remote_dispatch(:supports_optimizer_hints?)
        end

        def supports_partial_index?
          pure_remote_dispatch(:supports_partial_index?)
        end

        def supports_partitioned_indexes?
          pure_remote_dispatch(:supports_partitioned_indexes?)
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

        def supports_unique_constraints?
          pure_remote_dispatch(:supports_unique_constraints?)
        end

        def supports_update_returning?
          pure_remote_dispatch(:supports_update_returning?)
        end

        def supports_validate_constraints?
          pure_remote_dispatch(:supports_validate_constraints?)
        end

        def supports_views?
          pure_remote_dispatch(:supports_views?)
        end

        def supports_virtual_columns?
          pure_remote_dispatch(:supports_virtual_columns?)
        end

        # QUOTING =================================================

        def lookup_cast_type(...)
          remote_dispatch(:lookup_cast_type, ...)
        end

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

        def quoted_date(...)
          pure_remote_dispatch(:quoted_date, ...)
        end

        def type_cast(...)
          remote_dispatch(:type_cast, ...)
        end

        # DATABASE STATEMENTS =====================================

        def explain(...)
          remote_dispatch(:explain, ...)
        end

        def high_precision_current_timestamp
          remote_dispatch(:high_precision_current_timestamp)
        end

        def write_query?(...)
          remote_dispatch(:write_query?, ...)
        end

        # SCHEMA STATEMENTS =======================================

        def add_column(...)
          remote_dispatch(:add_column, ...)
        end

        def add_foreign_key(...)
          remote_dispatch(:add_foreign_key, ...)
        end

        def add_index(...)
          remote_dispatch(:add_index, ...)
        end

        def add_index_options(...)
          remote_dispatch(:add_index_options, ...)
        end

        def build_create_index_definition(...)
          remote_dispatch(:build_create_index_definition, ...)
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

        def change_foreign_key(...)
          remote_dispatch(:change_foreign_key, ...)
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

        def create_schema_dumper(...)
          remote_dispatch(:create_schema_dumper, ...)
        end

        def default_sequence_name(...)
          remote_dispatch(:default_sequence_name, ...)
        end

        def drop_table(...)
          remote_dispatch(:drop_table, ...)
        end

        def foreign_key_column_for(...)
          remote_dispatch(:foreign_key_column_for, ...)
        end

        def foreign_keys(...)
          remote_dispatch(:foreign_keys, ...)
        end

        def index_name(...)
          remote_dispatch(:index_name, ...)
        end

        def index_name_exists?(...)
          remote_dispatch(:index_name_exists?, ...)
        end

        def indexes(...)
          remote_dispatch(:indexes, ...)
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

        def table_comment(...)
          remote_dispatch(:table_comment, ...)
        end

        def type_to_sql(...)
          pure_remote_dispatch(:type_to_sql, ...)
        end

        def update_table_definition(...)
          remote_dispatch(:update_table_definition, ...)
        end

        # ADAPTER SPECIFIC ========================================

        def add_enum_value(...)
          remote_dispatch(:add_enum_value, ...)
        end

        def build_insert_sql(...)
          remote_dispatch(:build_insert_sql, ...)
        end

        def create_enum(...)
          remote_dispatch(:create_enum, ...)
        end

        def default_index_type?(...)
          remote_dispatch(:default_index_type?, ...)
        end

        def disable_extension(...)
          remote_dispatch(:disable_extension, ...)
        end

        def drop_enum(...)
          remote_dispatch(:drop_enum, ...)
        end

        def enable_extension(...)
          remote_dispatch(:enable_extension, ...)
        end

        def extensions
          remote_dispatch(:extensions)
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

        def max_identifier_length
          remote_dispatch(:max_identifier_length)
        end

        def release_advisory_lock(...)
          remote_dispatch(:release_advisory_lock, ...)
        end

        def rename_enum(...)
          remote_dispatch(:rename_enum, ...)
        end

        def rename_enum_value(...)
          remote_dispatch(:rename_enum_value, ...)
        end

        private
          # DATABASE STATEMENTS =====================================

          def build_truncate_statements(...)
            remote_dispatch(:build_truncate_statements, ...)
          end

          def warning_ignored?(...)
            remote_dispatch(:warning_ignored?, ...)
          end

          # SCHEMA STATEMENTS =======================================

          def add_options_for_index_columns(...)
            remote_dispatch(:add_options_for_index_columns, ...)
          end

          def change_column_comment_sql(...)
            remote_dispatch(:change_column_comment_sql, ...)
          end

          def change_index_comment_sql(...)
            remote_dispatch(:change_index_comment_sql, ...)
          end

          def change_table_comment_sql(...)
            remote_dispatch(:change_table_comment_sql, ...)
          end

          def create_alter_table(...)
            remote_dispatch(:create_alter_table, ...)
          end

          def data_source_sql(...)
            remote_dispatch(:data_source_sql, ...)
          end

          def drop_table_sql(...)
            remote_dispatch(:drop_table_sql, ...)
          end

          def extract_foreign_key_action(...)
            remote_dispatch(:extract_foreign_key_action, ...)
          end

          def fetch_table_options(...)
            remote_dispatch(:fetch_table_options, ...)
          end

          def fetch_type_metadata(...)
            remote_dispatch(:fetch_type_metadata, ...)
          end

          def quoted_scope(...)
            pure_remote_dispatch(:quoted_scope, ...)
          end

          def reference_name_for_table(...)
            remote_dispatch(:reference_name_for_table, ...)
          end

          def validate_table_length!(...)
            remote_dispatch(:validate_table_length!, ...)
          end

          # ADAPTER SPECIFIC ========================================

          def can_perform_case_insensitive_comparison_for?(...)
            pure_remote_dispatch(:can_perform_case_insensitive_comparison_for?, ...)
          end

          def fetch_column_definitions(...)
            remote_dispatch(:fetch_column_definitions, ...)
          end
      end
    end
  end
end
