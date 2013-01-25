require 'abstract_unit'
require 'action_dispatch/middleware/session/abstract_store'

module ActionDispatch
  class Request
    class SessionTest < ActiveSupport::TestCase
      def test_create_adds_itself_to_env
        env = {}
        s = prepare_session env
        assert_equal s, env[Rack::Session::Abstract::ENV_SESSION_KEY]
      end

      def test_to_hash
        env = {}
        s = prepare_session env
        s['foo'] = 'bar'
        assert_equal 'bar', s['foo']
        assert_equal({'foo' => 'bar'}, s.to_hash)
      end

      def test_create_merges_old
        env = {}
        s = prepare_session env
        s['foo'] = 'bar'

        s1 = prepare_session env
        assert_not_equal s, s1
        assert_equal 'bar', s1['foo']
      end

      def test_find
        env = {}
        assert_nil Session.find(env)

        s = prepare_session env
        assert_equal s, Session.find(env)
      end

      def test_keys
        env = {}
        s = prepare_session env
        s['rails'] = 'ftw'
        s['adequate'] = 'awesome'
        assert_equal %w[rails adequate], s.keys
      end

      def test_values
        env = {}
        s = prepare_session env
        s['rails'] = 'ftw'
        s['adequate'] = 'awesome'
        assert_equal %w[ftw awesome], s.values
      end

      def test_clear
        env = {}
        s = prepare_session env
        s['rails'] = 'ftw'
        s['adequate'] = 'awesome'
        s.clear
        assert_equal([], s.values)
      end

      private
      def prepare_session(env)
        session_was = env[Request::Session::ENV_SESSION_KEY]
        env[Request::Session::ENV_SESSION_KEY] = Request::Session.new(self, env)

        class << env[Request::Session::ENV_SESSION_KEY]
          def load_session(*); [1, {}]; end
          def session_exists?(*); true; end
          def load!; @data = {}; @loaded = true; end
        end

        env[Request::Session::ENV_SESSION_OPTIONS_KEY] = Rack::Session::Abstract::ID::DEFAULT_OPTIONS
        env[Request::Session::ENV_SESSION_KEY].merge! session_was if session_was
        env[Request::Session::ENV_SESSION_KEY]
      end
    end
  end
end
