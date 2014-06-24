require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class AdapterLeasingTest < ActiveRecord::TestCase
      def setup
        @adapter = AbstractAdapter.new nil, nil
      end

      def test_owner
        assert_not @adapter.owner, 'adapter is not in use'
        assert @adapter.lease, 'lease adapter'
        assert @adapter.owner, 'adapter is in use'
      end

      def test_lease_twice
        assert first = @adapter.lease, 'should lease adapter'
        assert_equal first, @adapter.lease, 'should lease adapter to same thread'
      end

      def test_expire_mutates_owner
        assert @adapter.lease, 'lease adapter'
        assert @adapter.owner, 'adapter is in use'
        @adapter.expire
        assert_not @adapter.owner, 'adapter is in use'
      end

      def test_close
        pool = ConnectionPool.new ActiveRecord::Base.connection_pool.spec

        # Make sure the pool marks the connection in use
        assert @adapter = pool.connection
        assert @adapter.owner

        # Close should put the adapter back in the pool
        @adapter.close
        assert_not @adapter.owner

        assert_equal @adapter, pool.connection
      end
    end
  end
end