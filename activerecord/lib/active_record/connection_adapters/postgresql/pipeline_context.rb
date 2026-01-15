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
        # When true, consume PGRES_PIPELINE_SYNC results explicitly.
        # When false, skip them during result collection (using get_result loop).
        # True is needed for concurrent result collection; false is simpler for now.
        # SyncIntent markers are always recorded to track sync boundaries.
        TRACK_SYNCS = false

        # Marker for sync points in the pipeline.
        class SyncIntent # :nodoc:
          attr_accessor :raw_result

          def raw_result_available?
            !@raw_result.nil?
          end
        end

        def pipeline_active?
          @lock.synchronize do
            connected? && @raw_connection.pipeline_status != PG::PQ_PIPELINE_OFF
          end
        end

        def pipeline_pending?
          @lock.synchronize do
            @pending_intents ||= []
            @pending_intents.any?
          end
        end

        def enter_pipeline_mode
          @lock.synchronize do
            return if pipeline_active?
            raise "Cannot enter pipeline mode: pipelining is locked" if @pipelining_locked

            unless connected?
              raise ActiveRecord::ConnectionFailed, "Connection is not usable while entering pipeline mode"
            end

            @raw_connection.enter_pipeline_mode
          end
        end

        def pipeline_sync
          @lock.synchronize do
            return unless pipeline_active?

            @pending_intents ||= []
            @pending_intents << SyncIntent.new

            @raw_connection.pipeline_sync
          end
        end

        def exit_pipeline_mode
          @lock.synchronize do
            return unless pipeline_active?
            raise "Cannot exit pipeline mode: pipelining is locked" if @pipelining_locked

            begin
              flush_pipeline if connected?
            ensure
              abandon_pipelined_intents

              if connected?
                begin
                  # Drain any unconsumed results (e.g. from replay or
                  # a failed flush) so we can cleanly exit pipeline mode.
                  @raw_connection.pipeline_sync
                  loop do
                    result = @raw_connection.get_result
                    break unless result
                  end
                rescue PG::Error
                  # Connection dead, can't discard
                end
              end
            end

            if connected?
              begin
                @raw_connection.exit_pipeline_mode
              rescue PG::Error
                # Pipeline still dirty (e.g. unconsumed results from a
                # failed flush). Close the connection so it gets
                # re-established on next use.
                @raw_connection.close rescue nil
              end
            else
              @raw_connection&.check_socket
            end
          end
        end

        # Add a query intent to the pipeline.
        # The intent's raw_result will be populated when the pipeline is flushed.
        def pipeline_add_query(intent)
          @lock.synchronize do
            raise "Pipeline mode not active" unless pipeline_active?

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
            return unless pipeline_pending?

            pipeline_sync
            consume_pipeline
          end
        end

        def consume_pipeline
          @lock.synchronize do
            @pending_intents ||= []
            return if @pending_intents.empty?

            while intent = @pending_intents.first
              if intent.is_a?(SyncIntent) && !TRACK_SYNCS
                @pending_intents.shift
                next
              end

              raw_result = get_result(@raw_connection) { |result|
                if result.result_status == PG::PGRES_PIPELINE_SYNC
                  TRACK_SYNCS ? :break : :skip
                end
              }
              @pending_intents.shift

              if raw_result&.result_status == PG::PGRES_PIPELINE_ABORTED
                intent.deliver_not_run(reason: :server_aborted)
                next
              end

              # Check if the result contains an error
              begin
                raw_result&.check
              rescue => e
                translated = translate_exception_with_cause(e, intent.processed_sql, intent.binds)
                intent.deliver_failure(translated)
                next
              end

              # Update notification payload (like perform_query does for sync path)
              if intent.notification_payload && raw_result
                intent.notification_payload[:affected_rows] = raw_result.cmd_tuples
                intent.notification_payload[:row_count] = raw_result.ntuples
              end

              intent.deliver_result(raw_result)
            end
          end
        end

        private
          def abandon_pipelined_intents
            intents = @pending_intents
            @pending_intents = []

            return unless intents&.any?

            error = ActiveRecord::ConnectionFailed.new("Connection lost during pipeline execution")
            intents.each do |intent|
              next if intent.is_a?(SyncIntent)
              next if intent.raw_result_available?
              intent.deliver_failure(error)
            end
          end
      end
    end
  end
end
