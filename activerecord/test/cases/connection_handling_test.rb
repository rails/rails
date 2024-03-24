# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class ConnectionHandlingTest < ActiveRecord::TestCase
    unless in_memory_db?
      test "#with_connection lease the connection for the duration of the block" do
        ActiveRecord::Base.connection_pool.release_connection
        assert_not_predicate ActiveRecord::Base.connection_pool, :active_connection?

        ActiveRecord::Base.with_connection do |connection|
          assert_predicate ActiveRecord::Base.connection_pool, :active_connection?
        end

        assert_not_predicate ActiveRecord::Base.connection_pool, :active_connection?
      end

      test "#connection makes the lease permanent even inside #with_connection" do
        ActiveRecord::Base.connection_pool.release_connection
        assert_not_predicate ActiveRecord::Base.connection_pool, :active_connection?

        conn = nil
        ActiveRecord::Base.with_connection do |connection|
          conn = connection
          assert_predicate ActiveRecord::Base.connection_pool, :active_connection?
          2.times do
            assert_same connection, ActiveRecord::Base.lease_connection
          end
        end

        assert_predicate ActiveRecord::Base.connection_pool, :active_connection?
        assert_same conn, ActiveRecord::Base.lease_connection
      end

      test "#with_connection use the already leased connection if available" do
        leased_connection = ActiveRecord::Base.lease_connection
        assert_predicate ActiveRecord::Base.connection_pool, :active_connection?

        ActiveRecord::Base.with_connection do |connection|
          assert_same leased_connection, connection
          assert_same ActiveRecord::Base.lease_connection, connection
        end

        assert_predicate ActiveRecord::Base.connection_pool, :active_connection?
        assert_same ActiveRecord::Base.lease_connection, leased_connection
      end

      test "#with_connection is reentrant" do
        leased_connection = ActiveRecord::Base.lease_connection
        assert_predicate ActiveRecord::Base.connection_pool, :active_connection?

        ActiveRecord::Base.with_connection do |connection|
          assert_same leased_connection, connection
          assert_same ActiveRecord::Base.lease_connection, connection

          ActiveRecord::Base.with_connection do |connection2|
            assert_same leased_connection, connection2
            assert_same ActiveRecord::Base.lease_connection, connection2
          end
        end

        assert_predicate ActiveRecord::Base.connection_pool, :active_connection?
        assert_same ActiveRecord::Base.lease_connection, leased_connection
      end
    end
  end
end
