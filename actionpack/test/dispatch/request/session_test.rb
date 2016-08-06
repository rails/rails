require "abstract_unit"
require "action_dispatch/middleware/session/abstract_store"

module ActionDispatch
  class Request
    class SessionTest < ActiveSupport::TestCase
      attr_reader :req

      def setup
        @req = ActionDispatch::Request.empty
      end

      def test_create_adds_itself_to_env
        s = Session.create(store, req, {})
        assert_equal s, req.env[Rack::RACK_SESSION]
      end

      def test_to_hash
        s = Session.create(store, req, {})
        s["foo"] = "bar"
        assert_equal "bar", s["foo"]
        assert_equal({"foo" => "bar"}, s.to_hash)
      end

      def test_create_merges_old
        s = Session.create(store, req, {})
        s["foo"] = "bar"

        s1 = Session.create(store, req, {})
        assert_not_equal s, s1
        assert_equal "bar", s1["foo"]
      end

      def test_find
        assert_nil Session.find(req)

        s = Session.create(store, req, {})
        assert_equal s, Session.find(req)
      end

      def test_destroy
        s = Session.create(store, req, {})
        s["rails"] = "ftw"

        s.destroy

        assert_empty s
      end

      def test_keys
        s = Session.create(store, req, {})
        s["rails"] = "ftw"
        s["adequate"] = "awesome"
        assert_equal %w[rails adequate], s.keys
      end

      def test_values
        s = Session.create(store, req, {})
        s["rails"] = "ftw"
        s["adequate"] = "awesome"
        assert_equal %w[ftw awesome], s.values
      end

      def test_clear
        s = Session.create(store, req, {})
        s["rails"] = "ftw"
        s["adequate"] = "awesome"

        s.clear
        assert_empty(s.values)
      end

      def test_update
        s = Session.create(store, req, {})
        s["rails"] = "ftw"

        s.update(:rails => "awesome")

        assert_equal(["rails"], s.keys)
        assert_equal("awesome", s["rails"])
      end

      def test_delete
        s = Session.create(store, req, {})
        s["rails"] = "ftw"

        s.delete("rails")

        assert_empty(s.keys)
      end

      def test_fetch
        session = Session.create(store, req, {})

        session["one"] = "1"
        assert_equal "1", session.fetch(:one)

        assert_equal "2", session.fetch(:two, "2")
        assert_nil session.fetch(:two, nil)

        assert_equal "three", session.fetch(:three) {|el| el.to_s }

        assert_raise KeyError do
          session.fetch(:three)
        end
      end

      private
      def store
        Class.new {
          def load_session(env); [1, {}]; end
          def session_exists?(env); true; end
          def delete_session(env, id, options); 123; end
        }.new
      end
    end

    class SessionIntegrationTest < ActionDispatch::IntegrationTest
      class MySessionApp
        def call(env)
          request = Rack::Request.new(env)
          request.session["hello"] = "Hello from MySessionApp!"
          [ 200, {}, ["Hello from MySessionApp!"] ]
        end
      end

      Router = ActionDispatch::Routing::RouteSet.new
      Router.draw do
        get "/mysessionapp" => MySessionApp.new
      end

      def app
        @app ||= RoutedRackApp.new(Router)
      end

      def test_session_follows_rack_api_contract_1
        get "/mysessionapp"
        assert_response :ok
        assert_equal "Hello from MySessionApp!", @response.body
        assert_equal "Hello from MySessionApp!", session["hello"]
      end
    end
  end
end
