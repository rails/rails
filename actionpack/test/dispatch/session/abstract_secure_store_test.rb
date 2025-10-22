# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/middleware/session/abstract_store"

module ActionDispatch
  module Session
    class AbstractSecureStoreTest < ActiveSupport::TestCase
      class MemoryStore < AbstractSecureStore
        class SessionId < Rack::Session::SessionId
          attr_reader :cookie_value

          def initialize(session_id, cookie_value)
            super(session_id)
            @cookie_value = cookie_value
          end
        end

        def initialize(app)
          @sessions = {}
          super
        end

        def find_session(req, sid)
          sid ||= 1
          session = @sessions[sid] ||= {}
          [sid, session]
        end

        def write_session(req, sid, session, options)
          @sessions[sid] = SessionId.new(sid, session)
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
        assert Request::Session.find ActionDispatch::Request.new @env
      end

      def test_new_session_object_is_merged_with_old
        env = {}
        as = MemoryStore.new app
        as.call(env)

        assert @env
        session = Request::Session.find ActionDispatch::Request.new @env
        session["foo"] = "bar"

        as.call(@env)
        session1 = Request::Session.find ActionDispatch::Request.new @env

        assert_not_equal session, session1
        assert_equal session.to_hash, session1.to_hash
      end

      private
        def app(&block)
          @env = nil
          lambda { |env| @env = env }
        end
    end
  end
end
