require 'minitest/autorun'
require 'rails/configuration'
require 'active_support/test_case'

module Rails
  module Configuration
    class MiddlewareStackProxyTest < ActiveSupport::TestCase
      def setup
        @stack = MiddlewareStackProxy.new
      end

      def test_playback_insert_before
        @stack.insert_before :foo
        assert_playback :insert_before, :foo
      end

      def test_playback_insert_after
        @stack.insert_after :foo
        assert_playback :insert_after, :foo
      end

      def test_playback_swap
        @stack.swap :foo
        assert_playback :swap, :foo
      end

      def test_playback_use
        @stack.use :foo
        assert_playback :use, :foo
      end

      def test_playback_delete
        @stack.delete :foo
        assert_playback :delete, :foo
      end

      def test_order
        @stack.swap :foo
        @stack.delete :foo

        mock = MiniTest::Mock.new
        mock.expect :send, nil, [:swap, :foo]
        mock.expect :send, nil, [:delete, :foo]

        @stack.merge_into mock
        mock.verify
      end

      private

      def assert_playback(msg_name, args)
        mock = MiniTest::Mock.new
        mock.expect :send, nil, [msg_name, args]
        @stack.merge_into(mock)
        mock.verify
      end
    end
  end
end
