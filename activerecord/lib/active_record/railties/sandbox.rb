# frozen_string_literal: true

module ActiveRecord
  module Railties
    # = Active Record Sandbox
    #
    # Provides the sandbox implementation for Rails.sandbox { } API.
    # Supports multi-database setups by wrapping all connection pools
    # in transactions that are rolled back at the end of the block.
    module Sandbox
      class << self
        def run(&block)
          pools_with_transactions = []
          result = nil

          # Start transactions on all currently active connections
          each_connection_pool do |pool|
            if pool.active_connection?
              conn = pool.active_connection
              conn.begin_transaction(joinable: false, _lazy: false)
              pools_with_transactions << pool
            end
          end

          # Install checkout callback to wrap new connections
          callback = install_checkout_callback

          begin
            result = block.call
          ensure
            # Remove the checkout callback
            remove_checkout_callback(callback)

            # Rollback all transactions we started
            pools_with_transactions.each do |pool|
              if pool.active_connection?
                conn = pool.active_connection
                conn.rollback_transaction if conn.transaction_open?
              end
            end

            # Rollback transactions on any connections that were checked out
            # during the block (they got transactions via the checkout callback)
            each_connection_pool do |pool|
              next if pools_with_transactions.include?(pool)

              if pool.active_connection?
                conn = pool.active_connection
                conn.rollback_transaction if conn.transaction_open?
              end
            end
          end

          result
        end

        private
          def each_connection_pool(&block)
            ActiveRecord::Base.connection_handler.each_connection_pool(&block)
          end

          def install_checkout_callback
            callback = -> (conn) { conn.begin_transaction(joinable: false, _lazy: false) }

            ActiveRecord::ConnectionAdapters::AbstractAdapter.set_callback(:checkout, :after, callback)

            callback
          end

          def remove_checkout_callback(callback)
            ActiveRecord::ConnectionAdapters::AbstractAdapter.skip_callback(:checkout, :after, callback)
          end
      end
    end
  end
end
