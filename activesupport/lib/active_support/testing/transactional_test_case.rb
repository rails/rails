require "active_support/concern"
require "active_support/callbacks"

module ActiveSupport
  module Testing
    # Wraps the entire test case in a transaction.
    module TransactionalTestCase
      extend ActiveSupport::Concern

      included do
        class_attribute :use_transactional_test_case
        self.use_transactional_test_case = false

        setup_all do
          if use_transactional_test_case?
            @test_case_connections = enlist_transaction_connections
            @test_case_connections.each do |connection|
              connection.begin_transaction joinable: false, lock_thread: true
            end
          end
        end

        teardown_all do
          if use_transactional_test_case && @test_case_connections
            @test_case_connections.each do |connection|
              connection.rollback_transaction if connection.transaction_open?
            end
          end
        end

        private

          # Only select connections that support savepoints,
          # because individual test transactions will be nested
          # within the outer test case transaction.
          def enlist_transaction_connections
            ActiveRecord::Base.connection_handler.connection_pool_list.
              map(&:connection).
              select(&:supports_savepoints?)
          end
      end
    end
  end
end
