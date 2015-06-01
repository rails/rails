require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlerTest < ActiveRecord::TestCase
      def setup
        @klass    = Class.new(Base)   { def self.name; 'klass';    end }
        @subklass = Class.new(@klass) { def self.name; 'subklass'; end }

        @handler = ConnectionHandler.new
        @pool    = @handler.establish_connection(@klass, Base.connection_pool.spec)
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
        sub_pool = @handler.establish_connection(@subklass, Base.connection_pool.spec)
        assert_same sub_pool, @handler.retrieve_connection_pool(@subklass)

        @handler.remove_connection @subklass
        assert_same @pool, @handler.retrieve_connection_pool(@subklass)
      end

      def test_connection_pools
        assert_equal([@pool], @handler.connection_pools)
      end

      if Process.respond_to?(:fork)
        def test_connection_pool_per_pid
          object_id = ActiveRecord::Base.connection.object_id

          rd, wr = IO.pipe
          rd.binmode
          wr.binmode

          pid = fork {
            rd.close
            wr.write Marshal.dump ActiveRecord::Base.connection.object_id
            wr.close
            exit!
          }

          wr.close

          Process.waitpid pid
          assert_not_equal object_id, Marshal.load(rd.read)
          rd.close
        end

        def test_retrieve_connection_pool_copies_schema_cache_from_ancestor_pool
          @pool.schema_cache = @pool.connection.schema_cache
          @pool.schema_cache.add('posts')

          rd, wr = IO.pipe
          rd.binmode
          wr.binmode

          pid = fork {
            rd.close
            pool = @handler.retrieve_connection_pool(@klass)
            wr.write Marshal.dump pool.schema_cache.size
            wr.close
            exit!
          }

          wr.close

          Process.waitpid pid
          assert_equal @pool.schema_cache.size, Marshal.load(rd.read)
          rd.close
        end
      end
    end
  end
end
