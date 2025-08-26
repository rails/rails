# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class QueryIntent # :nodoc:
      attr_reader :raw_sql, :name, :binds, :prepare, :allow_retry,
                  :materialize_transactions, :batch
      attr_accessor :async, :processed_sql, :type_casted_binds, :notification_payload

      def initialize(raw_sql: nil, processed_sql: nil, name: "SQL", binds: [], prepare: false, async: false,
                     allow_retry: false, materialize_transactions: true, batch: false)
        if raw_sql.nil? && processed_sql.nil?
          raise ArgumentError, "Either raw_sql or processed_sql must be provided"
        end

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

      # Returns a hash representation of the QueryIntent for debugging/introspection
      def to_h
        {
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
