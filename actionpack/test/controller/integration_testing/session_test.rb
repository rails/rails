require "abstract_unit"
require "action_dispatch/integration_testing/session"

module ActionDispatch
  module IntegrationTesting
    class SessionTest < ActiveSupport::TestCase
      StubApp = lambda { |env|
        [200, { "Content-Type" => "text/html", "Content-Length" => "13" }, ["Hello, World!"]]
      }

      def setup
        @session = ActionDispatch::IntegrationTesting::Session.new(StubApp)
      end

      def test_https_bang_works_and_sets_truth_by_default
        assert !@session.https?
        @session.https!
        assert @session.https?
        @session.https! false
        assert !@session.https?
      end

      def test_host!
        assert_not_equal "glu.ttono.us", @session.host
        @session.host! "rubyonrails.com"
        assert_equal "rubyonrails.com", @session.host
      end

      def test_follow_redirect_raises_when_no_redirect
        @session.stub :redirect?, false do
          assert_raise(RuntimeError) { @session.follow_redirect! }
        end
      end

      def test_get
        path = "/index"; params = "blah"; headers = { location: "blah" }

        assert_called_with @session, :process, [:get, path, params: params, headers: headers] do
          @session.get(path, params: params, headers: headers)
        end
      end

      def test_get_with_env_and_headers
        path = "/index"; params = "blah"; headers = { location: "blah" }; env = { "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest" }
        assert_called_with @session, :process, [:get, path, params: params, headers: headers, env: env] do
          @session.get(path, params: params, headers: headers, env: env)
        end
      end

      def test_post
        path = "/index"; params = "blah"; headers = { location: "blah" }
        assert_called_with @session, :process, [:post, path, params: params, headers: headers] do
          @session.post(path, params: params, headers: headers)
        end
      end

      def test_patch
        path = "/index"; params = "blah"; headers = { location: "blah" }
        assert_called_with @session, :process, [:patch, path, params: params, headers: headers] do
          @session.patch(path, params: params, headers: headers)
        end
      end

      def test_put
        path = "/index"; params = "blah"; headers = { location: "blah" }
        assert_called_with @session, :process, [:put, path, params: params, headers: headers] do
          @session.put(path, params: params, headers: headers)
        end
      end

      def test_delete
        path = "/index"; params = "blah"; headers = { location: "blah" }
        assert_called_with @session, :process, [:delete, path, params: params, headers: headers] do
          @session.delete(path, params: params, headers: headers)
        end
      end

      def test_head
        path = "/index"; params = "blah"; headers = { location: "blah" }
        assert_called_with @session, :process, [:head, path, params: params, headers: headers] do
          @session.head(path, params: params, headers: headers)
        end
      end

      def test_xml_http_request_get
        path = "/index"; params = "blah"; headers = { location: "blah" }
        assert_called_with @session, :process, [:get, path, params: params, headers: headers, xhr: true] do
          @session.get(path, params: params, headers: headers, xhr: true)
        end
      end

      def test_xml_http_request_post
        path = "/index"; params = "blah"; headers = { location: "blah" }
        assert_called_with @session, :process, [:post, path, params: params, headers: headers, xhr: true] do
          @session.post(path, params: params, headers: headers, xhr: true)
        end
      end

      def test_xml_http_request_patch
        path = "/index"; params = "blah"; headers = { location: "blah" }
        assert_called_with @session, :process, [:patch, path, params: params, headers: headers, xhr: true] do
          @session.patch(path, params: params, headers: headers, xhr: true)
        end
      end

      def test_xml_http_request_put
        path = "/index"; params = "blah"; headers = { location: "blah" }
        assert_called_with @session, :process, [:put, path, params: params, headers: headers, xhr: true] do
          @session.put(path, params: params, headers: headers, xhr: true)
        end
      end

      def test_xml_http_request_delete
        path = "/index"; params = "blah"; headers = { location: "blah" }
        assert_called_with @session, :process, [:delete, path, params: params, headers: headers, xhr: true] do
          @session.delete(path, params: params, headers: headers, xhr: true)
        end
      end

      def test_xml_http_request_head
        path = "/index"; params = "blah"; headers = { location: "blah" }
        assert_called_with @session, :process, [:head, path, params: params, headers: headers, xhr: true] do
          @session.head(path, params: params, headers: headers, xhr: true)
        end
      end
    end
  end
end
