# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/middleware/session/abstract_store"

module ActionDispatch
  module Session
    class AbstractStoreTest < ActiveSupport::TestCase
      include CookieAssertions

      class MemoryStore < AbstractStore
        def initialize(app)
          @sessions = {}
          super
        end

        def find_session(env, sid)
          sid ||= 1
          session = @sessions[sid] ||= {}
          [sid, session]
        end

        def write_session(env, sid, session, options)
          @sessions[sid] = session
        end

        def session_exists?(req)
          true
        end
      end

      def test_session_is_set
        env = {}
        as = MemoryStore.new app
        as.call(env)

        assert @env
        assert ActionDispatch::Http::Session.find ActionDispatch::Request.new @env
      end

      def test_session_cookie_gets_same_site_from_env
        write_session = lambda do |env|
          ActionDispatch::Request.new(env).session["foo"] = "bar"
          [200, {}, []]
        end
        stack = ActionDispatch::Cookies.new(MemoryStore.new(write_session))
        env = Rack::MockRequest.env_for("/", "action_dispatch.cookies_same_site_protection" => proc { :strict })

        response = Rack::MockResponse.new(*stack.call(env))

        assert_set_cookie_attributes("_session_id", "SameSite=Strict", response.headers["set-cookie"])
      end

      def test_store_composed_from_the_mixins_gets_same_site_from_env
        store_class = Class.new(Rack::Session::Abstract::Persisted) do
          include Compatibility
          include StaleSessionCheck
          include SessionObject

          def find_session(req, sid) = [sid || generate_sid, {}]
          def write_session(req, sid, session, options) = sid
        end
        write_session = lambda do |env|
          ActionDispatch::Request.new(env).session["foo"] = "bar"
          [200, {}, []]
        end
        env = Rack::MockRequest.env_for("/", "action_dispatch.cookies_same_site_protection" => proc { :strict })

        response = Rack::MockResponse.new(*store_class.new(write_session).call(env))

        assert_set_cookie_attributes("_session_id", "SameSite=Strict", response.headers["set-cookie"])
      end

      def test_new_session_object_is_merged_with_old
        env = {}
        as = MemoryStore.new app
        as.call(env)

        assert @env
        session = ActionDispatch::Http::Session.find ActionDispatch::Request.new @env
        session["foo"] = "bar"

        as.call(@env)
        session1 = ActionDispatch::Http::Session.find ActionDispatch::Request.new @env

        assert_not_equal session, session1
        assert_equal session.to_hash, session1.to_hash
      end

      def test_update_raises_an_exception_if_arg_not_hashable
        env = {}
        as = MemoryStore.new app
        as.call(env)
        session = ActionDispatch::Http::Session.find ActionDispatch::Request.new env

        assert_raise TypeError do
          session.update("Not hashable")
        end
      end

      private
        def app(&block)
          @env = nil
          lambda { |env| @env = env }
        end
    end
  end
end
