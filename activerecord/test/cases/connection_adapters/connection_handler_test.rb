require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlerTest < ActiveRecord::TestCase
      def setup
        @handler = ConnectionHandler.new
        resolver = ConnectionAdapters::ConnectionSpecification::Resolver.new Base.configurations
        @spec_id = "primary"
        @pool    = @handler.establish_connection(resolver.spec(:arunit, @spec_id))
      end

      def test_establish_connection_uses_spec_id
        config = {"readonly" => {"adapter" => 'sqlite3'}}
        resolver = ConnectionAdapters::ConnectionSpecification::Resolver.new(config)
        spec =   resolver.spec(:readonly)
        @handler.establish_connection(spec)

        assert_not_nil @handler.retrieve_connection_pool('readonly')
      ensure
        @handler.remove_connection('readonly')
      end

      def test_retrieve_connection
        assert @handler.retrieve_connection(@spec_id)
      end

      def test_active_connections?
        assert !@handler.active_connections?
        assert @handler.retrieve_connection(@spec_id)
        assert @handler.active_connections?
        @handler.clear_active_connections!
        assert !@handler.active_connections?
      end

      def test_retrieve_connection_pool
        assert_not_nil @handler.retrieve_connection_pool(@spec_id)
      end

      def test_retrieve_connection_pool_with_invalid_id
        assert_nil @handler.retrieve_connection_pool("foo")
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
            pool = @handler.retrieve_connection_pool(@spec_id)
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
