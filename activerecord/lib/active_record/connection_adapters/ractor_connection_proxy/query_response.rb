# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionProxy < AbstractAdapter # :nodoc:
      # Shareable response for the main-side `query` operation.
      class QueryResponse
        attr_reader :columns, :rows, :affected_rows, :row_count, :last_inserted_id

        def initialize(result, affected_rows, row_count, last_inserted_id, warnings)
          @columns = RactorConnectionProxy.shareable_copy(result.columns)
          @rows = RactorConnectionProxy.shareable_copy(result.rows)
          @column_types_payload = RactorConnectionProxy.dump_column_types(result)
          @affected_rows = affected_rows
          @row_count = row_count
          @last_inserted_id = RactorConnectionProxy.shareable_copy(last_inserted_id)
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

        def warnings
          @warnings_payload ? Marshal.load(@warnings_payload) : []
        end

        def to_result
          column_types = @column_types_payload && Marshal.load(@column_types_payload)
          ActiveRecord::Result.new(@columns, @rows, column_types, affected_rows: @affected_rows)
        end
      end
    end
  end
end
