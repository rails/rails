# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      class AbstractProxyAdapter < AbstractAdapter # :nodoc:
        # Request for the main-side `query` operation.
        class QueryRequest
          attr_reader :sql, :name, :prepare, :batch, :allow_retry

          def initialize(sql:, name:, binds:, prepare:, batch:, allow_retry:)
            @prepare = !!prepare
            @batch = !!batch
            @allow_retry = !!allow_retry
            @sql = sql
            @name = name
            @binds_payload = Proxy.dump_binds(binds)
            ActiveSupport::Ractors.make_shareable(self)
          end

          def binds
            @binds_payload ? Marshal.load(@binds_payload) : []
          end

          # Perform query without main-side logging, transformers, or transaction bookkeeping.
          def perform(connection)
            intent = QueryIntent.new(
              adapter: connection,
              processed_sql: sql,
              name: name,
              binds: binds,
              prepare: prepare,
              allow_retry: allow_retry,
              materialize_transactions: false,
              batch: batch,
            )
            intent.notification_payload = {}

            result, warnings, last_inserted_id = connection.execute_raw_intent(intent)

            QueryResponse.new(
              result,
              intent.notification_payload[:affected_rows] || result.affected_rows,
              intent.notification_payload[:row_count] || result.length,
              last_inserted_id,
              warnings,
            )
          end
        end
      end
    end
  end
end
