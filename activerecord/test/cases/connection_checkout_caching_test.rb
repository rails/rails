# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class ConnectionCheckoutCachingTest < ActiveRecord::TestCase
    setup do
      @_cache_connection_checkout_was = ActiveRecord.cache_connection_checkout
      ActiveRecord::Base.release_connection
      ActiveRecord.cache_connection_checkout = false
    end

    teardown do
      ActiveRecord.cache_connection_checkout = @_cache_connection_checkout_was
    end

    test ".connection leases a connection if cache_connection_checkout is true" do
      ActiveRecord.cache_connection_checkout = true

      assert_not_predicate ActiveRecord::Base.connection_pool, :active_connection?
      ActiveRecord::Base.deprecated_connection
      assert_predicate ActiveRecord::Base.connection_pool, :active_connection?
    end

    test ".connection doesn't lease a connection by itself if cache_connection_checkout is false" do
      assert_not_predicate ActiveRecord::Base.connection_pool, :active_connection?
      ActiveRecord::Base.deprecated_connection
      assert_not_predicate ActiveRecord::Base.connection_pool, :active_connection?
    end

    test "performing a query doesn't permanently lease a connection" do
      conn = ActiveRecord::Base.deprecated_connection
      assert_not_predicate ActiveRecord::Base.connection_pool, :active_connection?

      assert_equal [[1]], conn.select_all("SELECT 1").rows
      assert_not_predicate ActiveRecord::Base.connection_pool, :active_connection?
    end
  end
end
