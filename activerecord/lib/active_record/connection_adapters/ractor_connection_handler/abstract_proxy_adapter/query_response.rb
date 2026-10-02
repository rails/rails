# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      class AbstractProxyAdapter < AbstractAdapter # :nodoc:
        # Shareable response for the main-side `query` operation; the worker
        # materializes it into a Result via `to_result`.
        class QueryResponse
          attr_reader :affected_rows, :row_count

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

          def to_result
            Result.new(
              @columns,
              @rows,
              @column_types_payload && Marshal.load(@column_types_payload),
              affected_rows: @affected_rows,
              warnings: @warnings_payload && Marshal.load(@warnings_payload),
              last_inserted_id: @last_inserted_id,
            )
          end
        end
      end
    end
  end
end
