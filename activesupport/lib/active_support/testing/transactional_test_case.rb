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
            @test_case_connections = enlist_fixture_connections
            @test_case_connections.each do |connection|
              connection.begin_transaction joinable: false
              connection.pool.lock_thread = true
            end
          end
        end

        teardown_all do
          if use_transactional_test_case && @test_case_connections
            @test_case_connections.each do |connection|
              connection.rollback_transaction if connection.transaction_open?
              connection.pool.lock_thread = false
            end
          end
        end
      end
    end
  end
end
