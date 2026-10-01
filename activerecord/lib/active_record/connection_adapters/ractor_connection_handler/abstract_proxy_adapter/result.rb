# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      class AbstractProxyAdapter < AbstractAdapter # :nodoc:
        # Worker-side replacement for a raw driver result, carrying rows and
        # adapter metadata captured before crossing the Ractor boundary.
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
