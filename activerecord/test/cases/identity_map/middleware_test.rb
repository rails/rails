require "cases/helper"

module ActiveRecord
  module IdentityMap
    class MiddlewareTest < ActiveRecord::TestCase
      def setup
        super
        @enabled = IdentityMap.enabled
        IdentityMap.enabled = false
      end

      def teardown
        super
        IdentityMap.enabled = @enabled
      end

      def test_delegates
        called = false
        mw = Middleware.new lambda { |env|
          called = true
        }
        mw.call({})
        assert called, 'middleware delegated'
      end

      def test_im_enabled_during_delegation
        mw = Middleware.new lambda { |env|
          assert IdentityMap.enabled?, 'identity map should be enabled'
        }
        mw.call({})
      end
    end
  end
end
