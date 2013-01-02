require 'abstract_unit'
require 'action_dispatch/middleware/session/abstract_store'

module ActionDispatch
  module Session
    class AbstractStoreTest < ActiveSupport::TestCase
      class MemoryStore < AbstractStore
        def initialize(app)
          @sessions = {}
          super
        end

        def get_session(env, sid)
          sid ||= 1
          session = @sessions[sid] ||= {}
          [sid, session]
        end

        def set_session(env, sid, session, options)
          @sessions[sid] = session
        end
      end

      def test_session_is_set
        env = {}
        as = MemoryStore.new app
        as.call(env)

        assert @env
        assert Request::Session.find @env
      end

      def test_new_session_object_is_merged_with_old
        env = {}
        as = MemoryStore.new app
        as.call(env)

        assert @env
        session = Request::Session.find @env
        session['foo'] = 'bar'

        as.call(@env)
        session1 = Request::Session.find @env

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
