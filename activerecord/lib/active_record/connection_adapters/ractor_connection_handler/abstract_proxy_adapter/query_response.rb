# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      class AbstractProxyAdapter < AbstractAdapter # :nodoc:
        # A shareable snapshot of the main-side query outcome.
        class QueryResponse
          attr_reader :columns, :rows, :affected_rows, :row_count, :last_inserted_id

          def initialize(result, affected_rows, row_count, last_inserted_id, warnings)
            @columns = result.columns
            @rows = result.rows
            @column_types_payload = Proxy.dump_column_types(result)
            @affected_rows = affected_rows
            @row_count = row_count
            @last_inserted_id = last_inserted_id
            @warnings_payload =
              unless warnings.nil? || warnings.empty?
                begin
                  Marshal.dump(warnings).freeze
                rescue TypeError
                  nil
                end
              end
            ActiveSupport::Ractors.make_shareable(self, copy: false)
          end

          def column_types
            @column_types_payload && Marshal.load(@column_types_payload)
          end

          def warnings
            @warnings_payload && Marshal.load(@warnings_payload)
          end
        end
      end
    end
  end
end
