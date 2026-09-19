# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      class AbstractProxyAdapter < AbstractAdapter # :nodoc:
        # The proxy's raw query result. Raw driver results cannot cross the
        # Ractor boundary, so the worker's `perform_query` yields a
        # materialized ActiveRecord::Result instead, carrying what the concrete
        # adapter read off the driver result on the main Ractor.
        class Result < ActiveRecord::Result
          attr_reader :warnings, :last_inserted_id

          def initialize(columns, rows, column_types, affected_rows:, warnings:, last_inserted_id:)
            super(columns, rows, column_types, affected_rows: affected_rows)
            @warnings = warnings
            @last_inserted_id = last_inserted_id
          end
        end
      end
    end
  end
end
