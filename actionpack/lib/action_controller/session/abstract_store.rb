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

        def session_id
          ActiveSupport::Deprecation.warn(
            "ActionController::Session::AbstractStore::SessionHash#session_id " +
            "has been deprecated. Please use request.session_options[:id] instead.", caller)
          @env[ENV_SESSION_OPTIONS_KEY][:id]
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
           "ActionController::Session::AbstractStore::SessionHash#data " +
           "has been deprecated. Please use #to_hash instead.", caller)
          to_hash
        end

        def inspect
          load! unless @loaded
          super
        end

        private
          def loaded?
            @loaded
          end

          def load!
            stale_session_check! do
              id, session = @by.send(:load_session, @env)
              (@env[ENV_SESSION_OPTIONS_KEY] ||= {})[:id] = id
              replace(session)
              @loaded = true
            end
          end

          def stale_session_check!
            yield
          rescue ArgumentError => argument_error
            if argument_error.message =~ %r{undefined class/module ([\w:]*\w)}
              begin
                # Note that the regexp does not allow $1 to end with a ':'
                $1.constantize
              rescue LoadError, NameError => const_error
                raise ActionController::SessionRestoreError, "Session contains objects whose class definition isn\\'t available.\nRemember to require the classes for all objects kept in the session.\n(Original exception: \#{const_error.message} [\#{const_error.class}])\n"
              end

              retry
            else
              raise
            end
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
          ActiveSupport::Deprecation.warn "Giving :session_path to SessionStore is deprecated, " <<
            "please use :path instead", caller
          options[:path] = options.delete(:session_path)
        end
        if options.has_key?(:session_key)
          ActiveSupport::Deprecation.warn "Giving :session_key to SessionStore is deprecated, " <<
            "please use :key instead", caller
          options[:key] = options.delete(:session_key)
        end
        if options.has_key?(:session_http_only)
          ActiveSupport::Deprecation.warn "Giving :session_http_only to SessionStore is deprecated, " <<
            "please use :httponly instead", caller
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

          sid = options[:id] || generate_sid

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
          unless headers[SET_COOKIE].blank?
            headers[SET_COOKIE] << "\n#{cookie}"
          else
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
