# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class QueryIntent # :nodoc:
      attr_reader :sql, :name, :binds, :prepare, :allow_retry,
                  :materialize_transactions, :batch
      attr_accessor :async, :type_casted_binds, :notification_payload

      def initialize(sql:, name: "SQL", binds: [], prepare: false, async: false,
                     allow_retry: false, materialize_transactions: true, batch: false)
        @sql = sql
        @name = name
        @binds = binds
        @prepare = prepare
        @async = async
        @allow_retry = allow_retry
        @materialize_transactions = materialize_transactions
        @batch = batch
        @type_casted_binds = nil
        @notification_payload = nil
      end

      # Returns a hash representation of the QueryIntent for debugging/introspection
      def to_h
        {
          sql: sql,
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
