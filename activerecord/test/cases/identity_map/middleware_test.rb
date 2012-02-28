require "cases/helper"
require "rack"

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
        IdentityMap.clear
      end

      def test_delegates
        called = false
        mw = Middleware.new lambda { |env|
          called = true
          [200, {}, nil]
        }
        mw.call({})
        assert called, 'middleware delegated'
      end

      def test_im_enabled_during_delegation
        mw = Middleware.new lambda { |env|
          assert IdentityMap.enabled?, 'identity map should be enabled'
          [200, {}, nil]
        }
        mw.call({})
      end

      class Enum < Struct.new(:iter)
        def each(&b)
          iter.call(&b)
        end
      end

      def test_im_enabled_during_body_each
        mw = Middleware.new lambda { |env|
          [200, {}, Enum.new(lambda { |&b|
            assert IdentityMap.enabled?, 'identity map should be enabled'
            b.call "hello"
          })]
        }
        body = mw.call({}).last
        body.each { |x| assert_equal 'hello', x }
      end

      def test_im_disabled_after_body_close
        mw = Middleware.new lambda { |env| [200, {}, []] }
        body = mw.call({}).last
        assert IdentityMap.enabled?, 'identity map should be enabled'
        body.close
        assert !IdentityMap.enabled?, 'identity map should be disabled'
      end

      def test_im_cleared_after_body_close
        mw = Middleware.new lambda { |env| [200, {}, []] }
        body = mw.call({}).last

        IdentityMap.repository['hello'] = 'world'
        assert !IdentityMap.repository.empty?, 'repo should not be empty'

        body.close
        assert IdentityMap.repository.empty?, 'repo should be empty'
      end
    end
  end
end
