require File.expand_path('../../helper', __FILE__)

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlerTest < ActiveRecord::TestCase
      def setup
        @handler = ConnectionHandler.new
        @handler.establish_connection 'america', Base.connection_pool.spec
        @klass = Struct.new(:name).new('america')
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
    end
  end
end
