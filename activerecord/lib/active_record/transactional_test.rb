require "active_support/concern"

module ActiveRecord
  # Wraps an individual test in a database transaction.
  module TransactionalTest
    extend ActiveSupport::Concern

    included do
      class_attribute :use_transactional_tests
      self.use_transactional_tests = true
    end

    def before_setup # :nodoc:
      setup_transaction
      super
    end

    def after_teardown # :nodoc:
      super
      teardown_transaction
    end

    def setup_transaction
      return unless run_in_transaction?

      @test_connections = []
      @connection_subscriber = nil

      # Begin transactions for connections already established
      @test_connections = enlist_test_connections
      @test_connections.each do |connection|
        connection.begin_transaction joinable: false
        connection.pool.lock_thread = true
      end

      # When connections are established in the future, begin a transaction too
      @connection_subscriber = ActiveSupport::Notifications.subscribe("!connection.active_record") do |_, _, _, _, payload|
        spec_name = payload[:spec_name] if payload.key?(:spec_name)

        if spec_name
          begin
            connection = ActiveRecord::Base.connection_handler.retrieve_connection(spec_name)
          rescue ConnectionNotEstablished
            connection = nil
          end

          if connection && !@test_connections.include?(connection)
            connection.begin_transaction joinable: false
            connection.pool.lock_thread = true
            @test_connections << connection
          end
        end
      end
    end

    def teardown_transaction
      return unless run_in_transaction?

      ActiveSupport::Notifications.unsubscribe(@connection_subscriber) if @connection_subscriber
      @test_connections.each do |connection|
        connection.rollback_transaction if connection.transaction_open?
        connection.pool.lock_thread = false
      end
      @test_connections.clear
    end

    private

      def enlist_test_connections
        ActiveRecord::Base.connection_handler.connection_pool_list.map(&:connection)
      end
  end
end
