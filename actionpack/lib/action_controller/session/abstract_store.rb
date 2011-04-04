require 'rack/utils'

module ActionController
  module Session
    class AbstractStore  
      ENV_SESSION_KEY = 'rack.session'.freeze
      ENV_SESSION_OPTIONS_KEY = 'rack.session.options'.freeze

      HTTP_COOKIE = 'HTTP_COOKIE'.freeze
      SET_COOKIE = 'Set-Cookie'.freeze

      # thin wrapper around Hash that allows us to lazily
      # load session id into session_options
      class OptionsHash < Hash
        def initialize(by, env, default_options)
          @by = by
          @env = env
          @session_id_loaded = false
          merge!(default_options)
        end

        def [](key)
          if key == :id
            load_session_id! unless super(:id) || has_session_id?
          end
          super(key)
        end

        private

          def has_session_id?
            @session_id_loaded
          end

          def load_session_id!
            self[:id] = @by.send(:extract_session_id, @env)
            @session_id_loaded = true
          end
      end

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
          load_for_read!
          super
        end

        def has_key?(key)
          load_for_read!
          super
        end

        def []=(key, value)
          load_for_write!
          super
        end

        def clear
          load_for_write!
          super
        end

        def to_hash
          load_for_read!
          h = {}.replace(self)
          h.delete_if { |k,v| v.nil? }
          h
        end

        def update(hash)
          load_for_write!
          super
        end

        def delete(key)
          load_for_write!
          super
        end

        def data
         ActiveSupport::Deprecation.warn(
           "ActionController::Session::AbstractStore::SessionHash#data " +
           "has been deprecated. Please use #to_hash instead.", caller)
          to_hash
        end

        def inspect
          load_for_read!
          super
        end

        def exists?
          return @exists if instance_variable_defined?(:@exists)
          @exists = @by.send(:exists?, @env)
        end

        def loaded?
          @loaded
        end

        def destroy
          clear
          @by.send(:destroy, @env) if @by
          @env[ENV_SESSION_OPTIONS_KEY][:id] = nil if @env && @env[ENV_SESSION_OPTIONS_KEY]
          @loaded = false
        end

        private
          
          def load_for_read!
            load! if !loaded? && exists?
          end

          def load_for_write!
            load! unless loaded?
          end

          def load!
            id, session = @by.send(:load_session, @env)
            @env[ENV_SESSION_OPTIONS_KEY][:id] = id
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
        prepare!(env)
        response = @app.call(env)

        session_data = env[ENV_SESSION_KEY]
        options = env[ENV_SESSION_OPTIONS_KEY]

        if !session_data.is_a?(AbstractStore::SessionHash) || session_data.loaded? || options[:expire_after]
          request = ActionController::Request.new(env)

          return response if (options[:secure] && !request.ssl?)
        
          session_data.send(:load!) if session_data.is_a?(AbstractStore::SessionHash) && !session_data.loaded?

          sid = options[:id] || generate_sid

          unless set_session(env, sid, session_data.to_hash)
            return response
          end

          request_cookies = env["rack.request.cookie_hash"]

          if (request_cookies.nil? || request_cookies[@key] != sid) || options[:expire_after]
            cookie = {:value => sid}
            cookie[:expires] = Time.now + options[:expire_after] if options[:expire_after]
            Rack::Utils.set_cookie_header!(response[1], @key, cookie.merge(options))
          end
        end

        response
      end

      private
      
        def prepare!(env)
          env[ENV_SESSION_KEY] = SessionHash.new(self, env)
          env[ENV_SESSION_OPTIONS_KEY] = OptionsHash.new(self, env, @default_options)
        end
      
        def generate_sid
          ActiveSupport::SecureRandom.hex(16)
        end

        def load_session(env)
          stale_session_check! do
            sid = current_session_id(env)
            sid, session = get_session(env, sid)
            [sid, session]
          end
        end
        
        def extract_session_id(env)
          stale_session_check! do
            request = Rack::Request.new(env)
            sid = request.cookies[@key]
            sid ||= request.params[@key] unless @cookie_only
            sid
          end
        end

        def current_session_id(env)
          env[ENV_SESSION_OPTIONS_KEY][:id]
        end
        
        def exists?(env)
          current_session_id(env).present?
        end

        def get_session(env, sid)
          raise '#get_session needs to be implemented.'
        end

        def set_session(env, sid, session_data)
          raise '#set_session needs to be implemented.'
        end
        
        def destroy(env)
          raise '#destroy needs to be implemented.'
        end
        
        module SessionUtils
          private
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
        include SessionUtils
    end
  end
end
