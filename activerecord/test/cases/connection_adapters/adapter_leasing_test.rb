# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class AdapterLeasingTest < ActiveRecord::TestCase
      class Pool < ConnectionPool
        def insert_connection_for_test!(c)
          synchronize do
            adopt_connection(c)
            @available.add c
          end
        end
      end

      def setup
        @adapter = AbstractAdapter.new nil, nil
      end

      def test_in_use?
        assert_not @adapter.in_use?, "adapter is not in use"
        assert @adapter.lease, "lease adapter"
        assert @adapter.in_use?, "adapter is in use"
      end

      def test_lease_twice
        assert @adapter.lease, "should lease adapter"
        assert_raises(ActiveRecordError) do
          @adapter.lease
        end
      end

      def test_expire_mutates_in_use
        assert @adapter.lease, "lease adapter"
        assert @adapter.in_use?, "adapter is in use"
        @adapter.expire
        assert_not @adapter.in_use?, "adapter is in use"
      end

      def test_close
        pool = Pool.new(ConnectionSpecification.new("primary", {}, nil))
        pool.insert_connection_for_test! @adapter
        @adapter.pool = pool

        # Make sure the pool marks the connection in use
        assert_equal @adapter, pool.connection
        assert_predicate @adapter, :in_use?

        # Close should put the adapter back in the pool
        @adapter.close
        assert_not_predicate @adapter, :in_use?

        assert_equal @adapter, pool.connection
      end
    end
  end
end
