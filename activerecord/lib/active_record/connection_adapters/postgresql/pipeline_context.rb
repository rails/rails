# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      # Manages PostgreSQL's pipeline mode for batching multiple queries
      # in a single network round-trip.
      #
      # Pipeline mode allows sending multiple queries without waiting for
      # results, then collecting all results together. This reduces latency
      # for sequences of queries that don't depend on each other's results.
      module PipelineContext # :nodoc:
        def pipeline_active?
          @lock.synchronize do
            connected? && @raw_connection.pipeline_status != PG::PQ_PIPELINE_OFF
          end
        end

        def enter_pipeline_mode
          @lock.synchronize do
            return if pipeline_active?
            @raw_connection.enter_pipeline_mode
          end
        end

        def exit_pipeline_mode
          @lock.synchronize do
            return unless pipeline_active?

            flush_pipeline

            @raw_connection.exit_pipeline_mode
          end
        end

        # Add a query intent to the pipeline.
        # The intent's raw_result will be populated when the pipeline is flushed.
        def pipeline_add_query(intent)
          @lock.synchronize do
            @pending_intents ||= []

            # Send the query to the pipeline.
            # Always use send_query_params in pipeline mode (even with empty binds array).
            @raw_connection.send_query_params(
              intent.processed_sql,
              intent.type_casted_binds || []
            )

            # Only add to pending list after successful send to avoid misalignment
            # if send_query_params raises an exception.
            @pending_intents << intent
          end

          intent
        end

        # Flush pending queries and collect results.
        def flush_pipeline
          @lock.synchronize do
            return unless pipeline_active?
            @pending_intents ||= []
            return if @pending_intents.empty?

            @raw_connection.pipeline_sync

            while intent = @pending_intents.shift
              intent.raw_result = consume_next_pipeline_result
            end
          end
        end

        private
          def consume_next_pipeline_result
            result = nil

            while true
              r = @raw_connection.get_result
              break unless r

              # Skip PGRES_PIPELINE_SYNC markers
              next if r.result_status == PG::PGRES_PIPELINE_SYNC

              result = r
            end

            result
          end
      end
    end
  end
end
