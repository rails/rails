# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class QueryIntent # :nodoc:
      attr_reader :arel, :name, :prepare, :allow_retry,
                  :materialize_transactions, :batch
      attr_writer :raw_sql
      attr_accessor :adapter, :binds, :async, :notification_payload, :raw_result

      def initialize(adapter:, arel: nil, raw_sql: nil, processed_sql: nil, name: "SQL", binds: [], prepare: false, async: false,
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
        @async = async
        @allow_retry = allow_retry
        @materialize_transactions = materialize_transactions
        @batch = batch
        @processed_sql = processed_sql
        @type_casted_binds = nil
        @notification_payload = nil
        @raw_result = nil
        @executed = false
        @write_query = nil
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
          async: async,
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

      # Prepares the intent for scheduling into async queue
      # Ensures SQL is preprocessed on current thread, then detaches adapter
      def schedule!
        # Force preprocessing on original thread before queuing
        processed_sql

        # Detach from original adapter while in queue
        @adapter = nil
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
        adapter.execute_intent(self) # sets our raw_result
        @executed = true
        nil
      end

      def finish
        affected_rows # just to consume/close the result
        nil
      end

      def cast_result
        raise "Cannot call cast_result before query has executed" unless @executed
        raise "Cannot call cast_result after affected_rows has been called" if defined?(@affected_rows)
        @cast_result ||= adapter.send(:cast_result, raw_result)
      end

      def affected_rows
        raise "Cannot call affected_rows before query has executed" unless @executed
        raise "Cannot call affected_rows after cast_result has been called" if defined?(@cast_result)
        @affected_rows ||= adapter.send(:affected_rows, raw_result)
      end

      private
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

          # We call tranformers after the write checks so we don't need to parse the
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
    end
  end
end
