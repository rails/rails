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
          assert_same connection, ActiveRecord::Base.connection
        end

        assert_not_predicate ActiveRecord::Base.connection_pool, :active_connection?
      end

      test "#with_connection use the already leased connection if available" do
        leased_connection = ActiveRecord::Base.connection
        assert_predicate ActiveRecord::Base.connection_pool, :active_connection?

        ActiveRecord::Base.with_connection do |connection|
          assert_same leased_connection, connection
          assert_same ActiveRecord::Base.connection, connection
        end

        assert_predicate ActiveRecord::Base.connection_pool, :active_connection?
        assert_same ActiveRecord::Base.connection, leased_connection
      end

      test "#with_connection is reentrant" do
        leased_connection = ActiveRecord::Base.connection
        assert_predicate ActiveRecord::Base.connection_pool, :active_connection?

        ActiveRecord::Base.with_connection do |connection|
          assert_same leased_connection, connection
          assert_same ActiveRecord::Base.connection, connection

          ActiveRecord::Base.with_connection do |connection2|
            assert_same leased_connection, connection2
            assert_same ActiveRecord::Base.connection, connection2
          end
        end

        assert_predicate ActiveRecord::Base.connection_pool, :active_connection?
        assert_same ActiveRecord::Base.connection, leased_connection
      end
    end
  end
end
