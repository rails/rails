module Rack

  module Session

    # Rack::Session::Cookie provides simple cookie based session management.
    # The session is a Ruby Hash stored as base64 encoded marshalled data
    # set to :key (default: rack.session).
    #
    # Example:
    #
    #     use Rack::Session::Cookie, :key => 'rack.session',
    #                                :domain => 'foo.com',
    #                                :path => '/',
    #                                :expire_after => 2592000
    #
    #     All parameters are optional.

    class Cookie

      def initialize(app, options={})
        @app = app
        @key = options[:key] || "rack.session"
        @default_options = {:domain => nil,
          :path => "/",
          :expire_after => nil}.merge(options)
      end

      def call(env)
        load_session(env)
        status, headers, body = @app.call(env)
        commit_session(env, status, headers, body)
      end

      private

      def load_session(env)
        request = Rack::Request.new(env)
        session_data = request.cookies[@key]

        begin
          session_data = session_data.unpack("m*").first
          session_data = Marshal.load(session_data)
          env["rack.session"] = session_data
        rescue
          env["rack.session"] = Hash.new
        end

        env["rack.session.options"] = @default_options.dup
      end

      def commit_session(env, status, headers, body)
        session_data = Marshal.dump(env["rack.session"])
        session_data = [session_data].pack("m*")

        if session_data.size > (4096 - @key.size)
          env["rack.errors"].puts("Warning! Rack::Session::Cookie data size exceeds 4K. Content dropped.")
          [status, headers, body]
        else
          options = env["rack.session.options"]
          cookie = Hash.new
          cookie[:value] = session_data
          cookie[:expires] = Time.now + options[:expire_after] unless options[:expire_after].nil?
          response = Rack::Response.new(body, status, headers)
          response.set_cookie(@key, cookie.merge(options))
          response.to_a
        end
      end

    end
  end
end
