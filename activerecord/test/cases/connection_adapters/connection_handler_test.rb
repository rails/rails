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
        assert_deprecated do
          assert_equal({ Base.connection_pool.spec => @pool }, @handler.connection_pools)
        end
      end

      def test_pool_from_any_process_for_uses_most_recent_spec
        skip unless current_adapter?(:SQLite3Adapter)

        file = Tempfile.new "lol.sqlite3"

        rd, wr = IO.pipe
        rd.binmode
        wr.binmode

        pid = fork do
          ActiveRecord::Base.configurations["arunit"]["database"] = file.path
          ActiveRecord::Base.establish_connection(:arunit)

          pid2 = fork do
            wr.write ActiveRecord::Base.connection_config[:database]
            wr.close
          end

          Process.waitpid pid2
        end

        Process.waitpid pid

        wr.close

        assert_equal file.path, rd.read

        rd.close
      ensure
        if file
          file.close
          file.unlink
        end
      end
    end
  end
end
