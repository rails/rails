# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class QueryIntent # :nodoc:
      attr_reader :arel, :name, :prepare, :allow_retry,
                  :materialize_transactions, :batch
      attr_accessor :raw_sql, :binds, :async, :processed_sql, :type_casted_binds, :notification_payload

      def initialize(arel: nil, raw_sql: nil, processed_sql: nil, name: "SQL", binds: [], prepare: false, async: false,
                     allow_retry: false, materialize_transactions: true, batch: false)
        if arel.nil? && raw_sql.nil? && processed_sql.nil?
          raise ArgumentError, "One of arel, raw_sql, or processed_sql must be provided"
        end

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
      end

      # Returns true if this QueryIntent contains an Arel AST that needs compilation
      def needs_arel_compilation?
        @arel && !@raw_sql && !@processed_sql
      end

      # Sets the results of Arel compilation
      # Called by the adapter after running to_sql_and_binds
      def set_compiled_result(raw_sql:, binds:, prepare:, allow_retry:)
        @raw_sql = raw_sql
        @binds = binds
        @prepare = prepare
        @allow_retry = allow_retry
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
    end
  end
end
