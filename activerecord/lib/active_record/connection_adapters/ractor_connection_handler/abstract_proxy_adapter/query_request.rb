# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      class AbstractProxyAdapter < AbstractAdapter # :nodoc:
        # Request for the main-side `query` operation. Always built
        # boundary-safe — binds are carried as an internal Marshal payload and
        # the request is made shareable — whether or not it crosses a Ractor
        # boundary, so a self-proxy run behaves exactly like a worker run.
        class QueryRequest
          attr_reader :sql, :name, :prepare, :batch, :allow_retry

          def initialize(sql:, name:, binds:, prepare:, batch:, allow_retry:)
            @prepare = !!prepare
            @batch = !!batch
            @allow_retry = !!allow_retry
            @sql = Proxy.shareable_copy(sql)
            @name = Proxy.shareable_copy(name)
            @binds_payload = Proxy.dump_binds(binds)
            ActiveSupport::Ractors.make_shareable(self, copy: false)
          end

          def binds
            @binds_payload ? Marshal.load(@binds_payload) : []
          end

          # Runs the request on the token-pinned physical connection (main
          # Ractor only). Executes below the public query pipeline: no
          # main-side intent logging, no query transformers, no main-side
          # transaction bookkeeping — only connection readiness, the concrete
          # adapter's `perform_query`, and result materialization.
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
            # Concrete `perform_query` implementations record row counts here.
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
