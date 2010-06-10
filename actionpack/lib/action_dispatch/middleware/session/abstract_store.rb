require 'rack/utils'
require 'rack/request'
require 'action_dispatch/middleware/cookies'
require 'active_support/core_ext/object/blank'

module ActionDispatch
  module Session
    class SessionRestoreError < StandardError #:nodoc:
    end

    class AbstractStore
      ENV_SESSION_KEY = 'rack.session'.freeze
      ENV_SESSION_OPTIONS_KEY = 'rack.session.options'.freeze

      class SessionHash < Hash
        def initialize(by, env)
          super()
          @by = by
          @env = env
          @loaded = false
        end

        def [](key)
          load! unless @loaded
          super(key.to_s)
        end

        def []=(key, value)
          load! unless @loaded
          super(key.to_s, value)
        end

        def to_hash
          h = {}.replace(self)
          h.delete_if { |k,v| v.nil? }
          h
        end

        def update(hash)
          load! unless @loaded
          super(hash.stringify_keys)
        end

        def delete(key)
          load! unless @loaded
          super(key.to_s)
        end

        def inspect
          load! unless @loaded
          super
        end

        def loaded?
          @loaded
        end

        private
          def load!
            stale_session_check! do
              id, session = @by.send(:load_session, @env)
              (@env[ENV_SESSION_OPTIONS_KEY] ||= {})[:id] = id
              replace(session.stringify_keys)
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
                raise ActionDispatch::Session::SessionRestoreError, "Session contains objects whose class definition isn't available.\nRemember to require the classes for all objects kept in the session.\n(Original exception: #{const_error.message} [#{const_error.class}])\n"
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
        @app = app
        @default_options = DEFAULT_OPTIONS.merge(options)
        @key = @default_options.delete(:key).freeze
        @cookie_only = @default_options.delete(:cookie_only)
        ensure_session_key!
      end

      def call(env)
        prepare!(env)
        response = @app.call(env)

        session_data = env[ENV_SESSION_KEY]
        options = env[ENV_SESSION_OPTIONS_KEY]

        if !session_data.is_a?(AbstractStore::SessionHash) || session_data.send(:loaded?) || options[:expire_after]
          session_data.send(:load!) if session_data.is_a?(AbstractStore::SessionHash) && !session_data.send(:loaded?)

          sid = options[:id] || generate_sid
          session_data = session_data.to_hash

          value = set_session(env, sid, session_data)
          return response unless value

          cookie = { :value => value }
          unless options[:expire_after].nil?
            cookie[:expires] = Time.now + options.delete(:expire_after)
          end

          request = ActionDispatch::Request.new(env)
          set_cookie(request, cookie.merge!(options))
        end

        response
      end

      private

        def prepare!(env)
          env[ENV_SESSION_KEY] = SessionHash.new(self, env)
          env[ENV_SESSION_OPTIONS_KEY] = @default_options.dup
        end

        def generate_sid
          ActiveSupport::SecureRandom.hex(16)
        end

        def set_cookie(request, options)
          request.cookie_jar[@key] = options
        end

        def load_session(env)
          request = Rack::Request.new(env)
          sid   = request.cookies[@key]
          sid ||= request.params[@key] unless @cookie_only
          sid, session = get_session(env, sid)
          [sid, session]
        end

        def ensure_session_key!
          if @key.blank?
            raise ArgumentError, 'A key is required to write a ' +
              'cookie containing the session data. Use ' +
              'config.session_store SESSION_STORE, { :key => ' +
              '"_myapp_session" } in config/application.rb'
          end
        end

        def get_session(env, sid)
          raise '#get_session needs to be implemented.'
        end

        def set_session(env, sid, session_data)
          raise '#set_session needs to be implemented and should return ' <<
            'the value to be stored in the cookie (usually the sid)'
        end
    end
  end
end
