require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlerTest < ActiveRecord::TestCase
      def setup
        @klass    = Class.new(Base)
        @subklass = Class.new(@klass)

        @parent   = Class.new(Base)
        @child    = Class.new(Base)

        @handler = ConnectionHandler.new

        @parent_pool = @handler.establish_connection(@parent, Base.connection_pool.spec)
        @child_pool = @handler.share_connection(@child, @parent)
        @pool    = @handler.establish_connection(@klass, Base.connection_pool.spec)
      end

      def test_retrieve_connection
        assert @handler.retrieve_connection(@klass)
        assert @handler.retrieve_connection(@parent)
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

      def test_establish_a_new_connection
        assert_not_equal @parent_pool, @pool
      end

      def test_return_from_share_connection
        assert_equal @child_pool, @parent_pool
      end

      def test_retrieve_shared_connection_after_establish
        @handler.establish_connection('foo', Base.connection_pool.spec)

        assert_same @handler.retrieve_connection_pool(@parent),
          @handler.retrieve_connection_pool(@child)
      end

      def test_retrieve_shared_connection_after_remove
        @handler.remove_connection(@child)

        assert_same @handler.retrieve_connection_pool(@parent),
          @handler.retrieve_connection_pool(@child)
      end

      def test_retrieve_connection_pool_uses_superclass_when_no_subclass_connection
        assert_not_nil @handler.retrieve_connection_pool(@subklass)
      end

      def test_retrieve_superclass_connection_after_establish
        @handler.establish_connection('foo', Base.connection_pool.spec)

        assert_same @handler.retrieve_connection_pool(@klass),
          @handler.retrieve_connection_pool(@subklass)
      end

      def test_retrieve_superclass_connection_after_remove
        @handler.remove_connection @subklass

        assert_same @handler.retrieve_connection_pool(@klass),
          @handler.retrieve_connection_pool(@subklass)
      end

      def test_connection_pools
        assert_deprecated do
          assert_equal({ Base.connection_pool.spec => @pool }, @handler.connection_pools)
        end
      end
    end
  end
end
