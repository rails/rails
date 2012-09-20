require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlerTest < ActiveRecord::TestCase
      def setup
        @klass    = Class.new { include ActiveRecord::Tag }
        @subklass = Class.new(@klass) { include ActiveRecord::Tag }

        @handler = ConnectionHandler.new
        @handler.establish_connection @klass, Base.connection_pool.spec
      end

      def test_retrieve_connection
        assert @handler.retrieve_connection(@klass)
      end

      def test_active_connections?
        assert !@handler.active_connections?
        assert @handler.retrieve_connection(@klass)
        assert @handler.active_connections?
        @handler.clear_active_connections!
        assert !@handler.active_connections?
      end

      def test_retrieve_connection_pool_with_ar_base
        assert_nil @handler.retrieve_connection_pool(ActiveRecord::Base)
      end

      def test_retrieve_connection_pool
        assert_not_nil @handler.retrieve_connection_pool(@klass)
      end

      def test_retrieve_connection_pool_uses_superclass_when_no_subclass_connection
        assert_not_nil @handler.retrieve_connection_pool(@subklass)
      end

      def test_retrieve_connection_pool_uses_superclass_pool_after_subclass_establish_and_remove
        @handler.establish_connection 'north america', Base.connection_pool.spec
        assert_same @handler.retrieve_connection_pool(@klass),
          @handler.retrieve_connection_pool(@subklass)

        @handler.remove_connection @subklass
        assert_same @handler.retrieve_connection_pool(@klass),
          @handler.retrieve_connection_pool(@subklass)
      end
    end
  end
end
