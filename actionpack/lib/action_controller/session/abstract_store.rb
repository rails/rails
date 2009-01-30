require 'rack/utils'

module ActionController
  module Session
    class AbstractStore
      ENV_SESSION_KEY = 'rack.session'.freeze
      ENV_SESSION_OPTIONS_KEY = 'rack.session.options'.freeze

      HTTP_COOKIE = 'HTTP_COOKIE'.freeze
      SET_COOKIE = 'Set-Cookie'.freeze

      class SessionHash < Hash
        def initialize(by, env)
          super()
          @by = by
          @env = env
          @loaded = false
        end

        def id
          load! unless @loaded
          @id
        end

        def session_id
          ActiveSupport::Deprecation.warn(
            "ActionController::Session::AbstractStore::SessionHash#session_id" +
            "has been deprecated.Please use #id instead.", caller)
          id
        end

        def [](key)
          load! unless @loaded
          super
        end

        def []=(key, value)
          load! unless @loaded
          super
        end

        def to_hash
          h = {}.replace(self)
          h.delete_if { |k,v| v.nil? }
          h
        end

        def data
         ActiveSupport::Deprecation.warn(
           "ActionController::Session::AbstractStore::SessionHash#data" +
           "has been deprecated.Please use #to_hash instead.", caller)
          to_hash
        end

        private
          def loaded?
            @loaded
          end

          def load!
            @id, session = @by.send(:load_session, @env)
            replace(session)
            @loaded = true
          end
      end

      DEFAULT_OPTIONS = {
        :key =>           '_session_id',
        :path =>          '/',
        :domain =>        nil,
        :expire_after =>  nil,
        :secure =>        false,
        :httponly =>      true,
        :cookie_only =>   true
      }

      def initialize(app, options = {})
        # Process legacy CGI options
        options = options.symbolize_keys
        if options.has_key?(:session_path)
          options[:path] = options.delete(:session_path)
        end
        if options.has_key?(:session_key)
          options[:key] = options.delete(:session_key)
        end
        if options.has_key?(:session_http_only)
          options[:httponly] = options.delete(:session_http_only)
        end

        @app = app
        @default_options = DEFAULT_OPTIONS.merge(options)
        @key = @default_options[:key]
        @cookie_only = @default_options[:cookie_only]
      end

      def call(env)
        session = SessionHash.new(self, env)

        env[ENV_SESSION_KEY] = session
        env[ENV_SESSION_OPTIONS_KEY] = @default_options.dup

        response = @app.call(env)

        session_data = env[ENV_SESSION_KEY]
        options = env[ENV_SESSION_OPTIONS_KEY]

        if !session_data.is_a?(AbstractStore::SessionHash) || session_data.send(:loaded?) || options[:expire_after]
          session_data.send(:load!) if session_data.is_a?(AbstractStore::SessionHash) && !session_data.send(:loaded?)

          if session_data.is_a?(AbstractStore::SessionHash)
            sid = session_data.id
          else
            sid = generate_sid
          end

          unless set_session(env, sid, session_data.to_hash)
            return response
          end

          cookie = Rack::Utils.escape(@key) + '=' + Rack::Utils.escape(sid)
          cookie << "; domain=#{options[:domain]}" if options[:domain]
          cookie << "; path=#{options[:path]}" if options[:path]
          if options[:expire_after]
            expiry = Time.now + options[:expire_after]
            cookie << "; expires=#{expiry.httpdate}"
          end
          cookie << "; Secure" if options[:secure]
          cookie << "; HttpOnly" if options[:httponly]

          headers = response[1]
          case a = headers[SET_COOKIE]
          when Array
            a << cookie
          when String
            headers[SET_COOKIE] = [a, cookie]
          when nil
            headers[SET_COOKIE] = cookie
          end
        end

        response
      end

      private
        def generate_sid
          ActiveSupport::SecureRandom.hex(16)
        end

        def load_session(env)
          request = Rack::Request.new(env)
          sid = request.cookies[@key]
          unless @cookie_only
            sid ||= request.params[@key]
          end
          sid, session = get_session(env, sid)
          [sid, session]
        end

        def get_session(env, sid)
          raise '#get_session needs to be implemented.'
        end

        def set_session(env, sid, session_data)
          raise '#set_session needs to be implemented.'
        end
    end
  end
end
