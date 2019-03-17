# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module DatabaseStatements
        private
          def execute_batch(sql, name = nil)
            if preventing_writes? && write_query?(sql)
              raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
            end

            materialize_transactions

            log(sql, name) do
              ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                @connection.execute_batch(sql)
              end
            end
          end

          def build_fixture_statements(fixture_set)
            fixture_set.flat_map do |table_name, fixtures|
              next if fixtures.empty?
              fixtures.map { |fixture| build_fixture_sql([fixture], table_name) }
            end.compact
          end

          def build_truncate_statements(*table_names)
            truncate_tables = table_names.map do |table_name|
              "DELETE FROM #{quote_table_name(table_name)}"
            end
            combine_multi_statements(truncate_tables)
          end
      end
    end
  end
end
