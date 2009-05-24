unless $LOAD_PATH.include?(File.expand_path(File.dirname(__FILE__) + "/.."))
  $LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))
end

require "uri"
require "rack"
require "rack/mock_session"
require "rack/test/cookie_jar"
require "rack/test/mock_digest_request"
require "rack/test/utils"
require "rack/test/methods"
require "rack/test/uploaded_file"

module Rack
  module Test

    VERSION = "0.3.0"

    DEFAULT_HOST = "example.org"
    MULTIPART_BOUNDARY = "----------XnJLe9ZIbbGUYtzPQJ16u1"

    # The common base class for exceptions raised by Rack::Test
    class Error < StandardError; end

    class Session
      extend Forwardable
      include Rack::Test::Utils

      def_delegators :@rack_mock_session, :clear_cookies, :set_cookie, :last_response, :last_request

      # Initialize a new session for the given Rack app
      def initialize(app, default_host = DEFAULT_HOST)
        @headers = {}
        @default_host = default_host
        @rack_mock_session = Rack::MockSession.new(app, default_host)
      end

      # Issue a GET request for the given URI with the given params and Rack
      # environment. Stores the issues request object in #last_request and
      # the app's response in #last_response. Yield #last_response to a block
      # if given.
      #
      # Example:
      #   get "/"
      def get(uri, params = {}, env = {}, &block)
        env = env_for(uri, env.merge(:method => "GET", :params => params))
        process_request(uri, env, &block)
      end

      # Issue a POST request for the given URI. See #get
      #
      # Example:
      #   post "/signup", "name" => "Bryan"
      def post(uri, params = {}, env = {}, &block)
        env = env_for(uri, env.merge(:method => "POST", :params => params))
        process_request(uri, env, &block)
      end

      # Issue a PUT request for the given URI. See #get
      #
      # Example:
      #   put "/"
      def put(uri, params = {}, env = {}, &block)
        env = env_for(uri, env.merge(:method => "PUT", :params => params))
        process_request(uri, env, &block)
      end

      # Issue a DELETE request for the given URI. See #get
      #
      # Example:
      #   delete "/"
      def delete(uri, params = {}, env = {}, &block)
        env = env_for(uri, env.merge(:method => "DELETE", :params => params))
        process_request(uri, env, &block)
      end

      # Issue a HEAD request for the given URI. See #get
      #
      # Example:
      #   head "/"
      def head(uri, params = {}, env = {}, &block)
        env = env_for(uri, env.merge(:method => "HEAD", :params => params))
        process_request(uri, env, &block)
      end

      # Issue a request to the Rack app for the given URI and optional Rack
      # environment. Stores the issues request object in #last_request and
      # the app's response in #last_response. Yield #last_response to a block
      # if given.
      #
      # Example:
      #   request "/"
      def request(uri, env = {}, &block)
        env = env_for(uri, env)
        process_request(uri, env, &block)
      end

      # Set a header to be included on all subsequent requests through the
      # session. Use a value of nil to remove a previously configured header.
      #
      # Example:
      #   header "User-Agent", "Firefox"
      def header(name, value)
        if value.nil?
          @headers.delete(name)
        else
          @headers[name] = value
        end
      end

      # Set the username and password for HTTP Basic authorization, to be
      # included in subsequent requests in the HTTP_AUTHORIZATION header.
      #
      # Example:
      #   basic_authorize "bryan", "secret"
      def basic_authorize(username, password)
        encoded_login = ["#{username}:#{password}"].pack("m*")
        header('HTTP_AUTHORIZATION', "Basic #{encoded_login}")
      end

      alias_method :authorize, :basic_authorize

      def digest_authorize(username, password)
        @digest_username = username
        @digest_password = password
      end

      # Rack::Test will not follow any redirects automatically. This method
      # will follow the redirect returned in the last response. If the last
      # response was not a redirect, an error will be raised.
      def follow_redirect!
        unless last_response.redirect?
          raise Error.new("Last response was not a redirect. Cannot follow_redirect!")
        end

        get(last_response["Location"])
      end

    private

      def env_for(path, env)
        uri = URI.parse(path)
        uri.host ||= @default_host

        env = default_env.merge(env)

        env.update("HTTPS" => "on")                if URI::HTTPS === uri
        env["X-Requested-With"] = "XMLHttpRequest" if env[:xhr]

        if (env[:method] == "POST" || env["REQUEST_METHOD"] == "POST") && !env.has_key?(:input)
          env["CONTENT_TYPE"] = "application/x-www-form-urlencoded"

          multipart = (Hash === env[:params]) &&
            env[:params].any? { |_, v| UploadedFile === v }

          if multipart
            env[:input] = multipart_body(env.delete(:params))
            env["CONTENT_LENGTH"] ||= env[:input].length.to_s
            env["CONTENT_TYPE"] = "multipart/form-data; boundary=#{MULTIPART_BOUNDARY}"
          else
            env[:input] = params_to_string(env.delete(:params))
          end
        end

        params = env[:params] || {}
        params.update(parse_query(uri.query))

        uri.query = requestify(params)

        if env.has_key?(:cookie)
          set_cookie(env.delete(:cookie), uri)
        end

        Rack::MockRequest.env_for(uri.to_s, env)
      end

      def process_request(uri, env)
        uri = URI.parse(uri)
        uri.host ||= @default_host

        @rack_mock_session.request(uri, env)

        if retry_with_digest_auth?(env)
          auth_env = env.merge({
            "HTTP_AUTHORIZATION"          => digest_auth_header,
            "rack-test.digest_auth_retry" => true
          })
          auth_env.delete('rack.request')
          process_request(uri.path, auth_env)
        else
          yield last_response if block_given?

          last_response
        end
      end

      def digest_auth_header
        challenge = last_response["WWW-Authenticate"].split(" ", 2).last
        params = Rack::Auth::Digest::Params.parse(challenge)

        params.merge!({
          "username"  => @digest_username,
          "nc"        => "00000001",
          "cnonce"    => "nonsensenonce",
          "uri"       => last_request.path_info,
          "method"    => last_request.env["REQUEST_METHOD"],
        })

        params["response"] = MockDigestRequest.new(params).response(@digest_password)

        "Digest #{params}"
      end

      def retry_with_digest_auth?(env)
        last_response.status == 401 &&
        digest_auth_configured? &&
        !env["rack-test.digest_auth_retry"]
      end

      def digest_auth_configured?
        @digest_username
      end

      def default_env
        { "rack.test" => true, "REMOTE_ADDR" => "127.0.0.1" }.merge(@headers)
      end

      def params_to_string(params)
        case params
        when Hash then requestify(params)
        when nil  then ""
        else params
        end
      end

    end

  end
end
