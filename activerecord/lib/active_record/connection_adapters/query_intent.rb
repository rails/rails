# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class QueryIntent # :nodoc:
      # Buffers instrumentation events during background execution for later publishing
      class EventBuffer
        def initialize(intent, instrumenter)
          @intent = intent
          @instrumenter = instrumenter
          @events = []
        end

        def instrument(name, payload = {}, &block)
          event = @instrumenter.new_event(name, payload)
          begin
            event.record(&block)
          ensure
            @events << event
          end
        end

        # Build a deferred handle for split start/finish logging.
        # Unlike the real instrumenter's build_handle (which notifies subscribers
        # immediately), this captures timing and queues for later publishing.
        def build_handle(name, payload)
          DeferredHandle.new(self, @instrumenter, name, payload)
        end

        # Add a finished event to the buffer for later publishing
        def add_event(event)
          @events << event
        end

        def flush
          events, @events = @events, []
          events.each do |event|
            event.payload[:lock_wait] = @intent.lock_wait
            ActiveSupport::Notifications.publish_event(event)
          end
        end

        # A handle that records timing but defers notification until buffer flush.
        # Mirrors the interface of ActiveSupport::Notifications::Fanout::Handle.
        class DeferredHandle
          def initialize(buffer, instrumenter, name, payload)
            @buffer = buffer
            @event = instrumenter.new_event(name, payload)
          end

          def start
            @event.start!
          end

          def finish
            @event.finish!
            @buffer.add_event(@event)
          end

          def payload
            @event.payload
          end
        end
      end

      attr_reader :arel, :name, :prepare, :allow_retry, :allow_async,
                  :materialize_transactions, :batch, :pool, :session, :lock_wait,
                  :retries_remaining, :retry_deadline, :error, :reconnectable,
                  :event_buffer, :not_run_reason
      attr_writer :raw_sql, :session
      attr_accessor :adapter, :binds, :ran_async, :notification_payload, :log_handle

      def initialize(adapter:, arel: nil, raw_sql: nil, processed_sql: nil, name: "SQL", binds: [], prepare: false, allow_async: false,
                     allow_retry: false, materialize_transactions: true, batch: false)
        if arel.nil? && raw_sql.nil? && processed_sql.nil?
          raise ArgumentError, "One of arel, raw_sql, or processed_sql must be provided"
        end

        @adapter = adapter
        @arel = arel
        @raw_sql = raw_sql
        @name = name
        @binds = binds
        @prepare = prepare
        @allow_async = allow_async
        @ran_async = nil
        @allow_retry = allow_retry
        @materialize_transactions = materialize_transactions
        @batch = batch
        @processed_sql = processed_sql
        @type_casted_binds = nil
        @notification_payload = nil
        @raw_result = nil
        @raw_result_available = false
        @executed = false
        @not_run_reason = nil
        @not_run_resettable = false
        @write_query = nil

        # Deferred execution state
        @pool = adapter.pool
        @session = nil
        @mutex = ActiveSupport::Concurrency::NullLock
        @error = nil
        @lock_wait = nil
        @event_buffer = nil
        @log_handle = nil

        # Retry tracking state (initialized when execution begins)
        @retries_remaining = nil
        @retry_deadline = nil
        @reconnectable = nil
      end

      # Returns a hash representation of the QueryIntent for debugging/introspection
      def to_h
        {
          arel: arel,
          raw_sql: raw_sql,
          processed_sql: processed_sql,
          name: name,
          binds: binds,
          prepare: prepare,
          allow_async: allow_async,
          allow_retry: allow_retry,
          materialize_transactions: materialize_transactions,
          batch: batch,
          type_casted_binds: type_casted_binds,
          notification_payload: notification_payload
        }
      end

      # Returns a string representation showing key attributes
      def inspect
        "#<#{self.class.name} name=#{name.inspect} allow_retry=#{allow_retry} materialize_transactions=#{materialize_transactions}>"
      end

      # Called by background thread to execute if not already done
      def execute_or_skip
        return unless pending?

        @session.synchronize do
          return unless pending?

          @pool.with_connection do |connection|
            return unless @mutex.try_lock
            previous_instrumenter = ActiveSupport::IsolatedExecutionState[:active_record_instrumenter]
            begin
              if pending?
                @event_buffer = EventBuffer.new(self, ActiveSupport::Notifications.instrumenter)
                ActiveSupport::IsolatedExecutionState[:active_record_instrumenter] = @event_buffer

                @adapter = connection
                @ran_async = true
                run_query!

                # If pipelined, flush with instrumentation before releasing connection
                flush_pipelined_result(connection) unless @raw_result_available
              end
            rescue => error
              @error = error
            ensure
              ActiveSupport::IsolatedExecutionState[:active_record_instrumenter] = previous_instrumenter
              @mutex.unlock
            end
          end
        end
      end

      # Is this intent still pending (result not yet available)?
      def pending?
        !@raw_result_available && @session&.active?
      end

      # Was this intent canceled?
      def canceled?
        @session && !@session.active?
      end

      def cancel
        return unless pending?
        @error = FutureResult::Canceled.new
      end

      # Returns raw SQL, compiling from arel if needed, memoized
      def raw_sql
        @raw_sql ||
          begin
            compile_arel!
            @raw_sql
          end
      end

      # Returns preprocessed SQL, memoized
      def processed_sql
        @processed_sql ||= preprocess_query
      end

      def type_casted_binds
        @type_casted_binds ||=
          begin
            compile_arel!
            adapter.type_casted_binds(binds)
          end
      end

      def has_binds?
        compile_arel!
        binds && !binds.empty?
      end

      def execute!
        if can_run_async?
          async_schedule!(ActiveRecord::Base.asynchronous_queries_session)
        else
          @ran_async = false
          run_query!
        end
      ensure
        @executed = true
      end

      def future_result
        if pending? || can_run_async?
          FutureResult.new(self)
        else
          FutureResult.wrap(cast_result)
        end
      end

      def finish
        affected_rows # just to consume/close the result
        nil
      end

      # Internal setter for raw result
      def raw_result=(value)
        adapter.lock.synchronize do
          @raw_result = value
          @raw_result_available = true
        end
      end

      # Deliver a successful result to this intent.
      # Handles logging, transaction dirtying, and marks the intent complete.
      def deliver_result(value)
        adapter.lock.synchronize do
          @raw_result = value
          @error = nil

          adapter.send(:handle_warnings, value, processed_sql)
          adapter.send(:dirty_current_transaction) if @materialize_transactions

          @raw_result_available = true
        end

        # Logging outside lock to avoid blocking other threads
        adapter.finish_intent_log(self)
      end

      # Deliver a failure to this intent.
      # Handles retry logic internally - if retriable, will attempt again.
      # Otherwise marks as permanent failure with logging and transaction dirtying.
      def deliver_failure(exception)
        should_finish_log = false

        adapter.lock.synchronize do
          @error = exception

          if retriable?
            action = adapter.send(:classify_retry_action, exception, reconnectable: @reconnectable)
            if action
              consume_retry
              reset_for_retry

              case action
              when :retry_query
                adapter.send(:backoff, adapter.send(:connection_retries) - @retries_remaining)
              when :retry_after_reconnect
                replayable = adapter.send(:abandon_pipelined_intents, exception, allow_recovery: true)
                adapter.reconnect!(restore_transactions: true)
                @reconnectable = false

                if replayable
                  # All intents are eligible for replay. Re-enter pipeline
                  # mode and re-queue everything, preserving original order:
                  # self was shifted off @pending_intents before deliver_failure
                  # was called, so it precedes the replayable intents.
                  # consume_pipeline will drain the replayed results.
                  adapter.enter_pipeline_mode
                  adapter.pipeline_add_query(self)
                  replayable.each { |intent| adapter.pipeline_add_query(intent) }
                  adapter.pipeline_sync
                  return
                end
              end

              adapter.perform_sync_attempt(self)
              return
            end
          end

          # Permanent failure
          adapter.send(:mark_connection_unhealthy_unless_query_error, exception)
          adapter.send(:dirty_current_transaction) if @materialize_transactions

          @raw_result_available = true
          should_finish_log = true
        end

        # Logging outside lock to avoid blocking other threads
        adapter.finish_intent_log(self, exception: exception) if should_finish_log
      end

      # Mark this intent as not run, with an explicit reason and reset policy.
      #
      # When +resettable+ is true, accessing the result will trigger on-demand
      # re-execution rather than raising QueryNotRun.
      #
      # All current pipelining is AR-internal, so +resettable+ is always true
      # today. A future manual batching API would set +resettable: false+ so
      # that callers observe QueryNotRun for server-aborted queries.
      def deliver_not_run(reason:, resettable: true)
        @not_run_reason = reason
        @not_run_resettable = resettable
        @raw_result_available = true
      end

      # Initialize retry tracking state from adapter configuration.
      # Called when beginning execution attempts.
      def initialize_retry_state(retries:, deadline:, reconnectable:)
        @retries_remaining = retries
        @retry_deadline = deadline
        @reconnectable = reconnectable
      end

      # Decrement retries remaining. Returns true if retry is still possible.
      def consume_retry
        return false unless @retries_remaining && @retries_remaining > 0
        return false if retry_deadline_exceeded?
        @retries_remaining -= 1
        true
      end

      # Check if the retry deadline has passed
      def retry_deadline_exceeded?
        @retry_deadline && @retry_deadline < Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # Check if this intent can still be retried
      def retriable?
        @allow_retry && @retries_remaining && @retries_remaining > 0 && !retry_deadline_exceeded?
      end

      # Reset state to allow another attempt
      def reset_for_retry
        @raw_result = nil
        @raw_result_available = false
        @error = nil
      end

      # Check if result has been populated yet (without blocking)
      def raw_result_available?
        @raw_result_available
      end

      # Access the raw result, ensuring it's available first
      def raw_result
        ensure_result
        @raw_result
      end

      # Ensure the result is available, blocking if necessary
      def ensure_result
        if @session
          # Async was scheduled: wait for result (sets lock_wait)
          execute_or_wait
        elsif !@raw_result_available
          # Result not available - flush pipeline to get it
          flush_pipelined_result(adapter)
        end

        @event_buffer&.flush

        if @not_run_reason
          if @not_run_resettable
            reset_for_rerun
            adapter.perform_sync_attempt(self)
          else
            raise ActiveRecord::QueryNotRun.new("Query was not run due to pipeline failure (#{@not_run_reason})")
          end
        end

        # Raise any error captured during deferred execution
        raise @error if @error

        # Check if the result contains an error (for pipelined queries)
        # Pipeline results defer errors until the result is accessed.
        if @raw_result.respond_to?(:check)
          begin
            @raw_result.check
          rescue => e
            raise adapter.send(:translate_exception_class, e, processed_sql, binds)
          end
        end
      end

      def cast_result
        raise "Cannot call cast_result before query has executed" unless @executed
        raise "Cannot call cast_result after affected_rows has been called" if defined?(@affected_rows)
        return @cast_result if defined?(@cast_result)

        ensure_result
        @cast_result = adapter.send(:cast_result, @raw_result)
      end

      def affected_rows
        raise "Cannot call affected_rows before query has executed" unless @executed
        raise "Cannot call affected_rows after cast_result has been called" if defined?(@cast_result)
        return @affected_rows if defined?(@affected_rows)

        ensure_result
        @affected_rows = adapter.send(:affected_rows, @raw_result)
      end

      private
        def reset_for_rerun
          @raw_result = nil
          @raw_result_available = false
          @error = nil
          @not_run_reason = nil
          @not_run_resettable = false
          remove_instance_variable(:@cast_result) if defined?(@cast_result)
          remove_instance_variable(:@affected_rows) if defined?(@affected_rows)
        end

        def flush_pipelined_result(connection)
          # Just flush the pipeline - logging is handled by start/finish_intent_log
          # via deliver_result called from consume_pipeline
          connection.flush_pipeline
        end

        def async_schedule!(session)
          if adapter.current_transaction.joinable?
            raise AsynchronousQueryInsideTransactionError, "Asynchronous queries are not allowed inside transactions"
          end

          # Upgrade to real mutex now that we'll have concurrent access
          @mutex = Mutex.new
          @session = session

          # Force preprocessing on original thread before queuing
          processed_sql

          # Detach from original adapter while in queue
          @adapter = nil

          # Schedule on the pool's async queue
          @pool.schedule_query(self)
        end

        # Heuristically guesses whether this is a write query by examining the outermost
        # SQL operation. Subqueries, function calls, etc are not considered.
        def write_query?
          return @write_query unless @write_query.nil?

          @write_query =
            case arel
            when Arel::SelectManager
              false
            when Arel::InsertManager, Arel::UpdateManager, Arel::DeleteManager
              true
            else
              adapter.write_query?(raw_sql)
            end
        end

        def preprocess_query
          if adapter.preventing_writes? && write_query?
            raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{raw_sql}"
          end

          sql = raw_sql

          # We call transformers after the write checks so we don't need to parse the
          # transformed result (which probably just adds comments we'd need to ignore).
          # This means we assume no transformer will change a read into a write.
          ActiveRecord.query_transformers&.each do |transformer|
            sql = transformer.call(sql, adapter)
          end

          sql
        end

        def compile_arel!
          return if @raw_sql || !@arel
          @raw_sql, @binds, @prepare, @allow_retry = adapter.to_sql_and_binds(@arel, @binds, @prepare, @allow_retry)
          nil
        end

        # Block until result is available, or execute as foreground fallback
        def execute_or_wait
          return (@lock_wait = 0.0) if @raw_result_available

          start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
          @mutex.synchronize do
            if pending?
              @pool.with_connection do |connection|
                @adapter = connection
                @ran_async = false  # Foreground fallback, not actually async
                run_query!

                # If pipelined, flush with instrumentation before releasing connection
                flush_pipelined_result(connection) unless @raw_result_available
              end
            else
              # Result was computed by background thread while we waited for mutex
              @lock_wait = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond) - start
            end
          rescue => error
            @error = error
          end
        end

        def can_run_async?
          @allow_async && adapter.async_enabled?
        end

        def run_query!
          adapter.execute_intent(self)
        rescue ::RangeError
          @cast_result = ActiveRecord::Result.empty
          @raw_result_available = true
        end
    end
  end
end
