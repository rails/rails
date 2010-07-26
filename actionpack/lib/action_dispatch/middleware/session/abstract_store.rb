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
            load_session_id! unless key?(:id) || has_session_id?
          end
          super
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

        def [](key)
          load_for_read!
          super(key.to_s)
        end

        def has_key?(key)
          load_for_read!
          super(key.to_s)
        end

        def []=(key, value)
          load_for_write!
          super(key.to_s, value)
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
          super(hash.stringify_keys)
        end

        def delete(key)
          load_for_write!
          super(key.to_s)
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
            replace(session.stringify_keys)
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

        if !session_data.is_a?(AbstractStore::SessionHash) || session_data.loaded? || options[:expire_after]
          session_data.send(:load!) if session_data.is_a?(AbstractStore::SessionHash) && !session_data.loaded?

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
          env[ENV_SESSION_OPTIONS_KEY] = OptionsHash.new(self, env, @default_options)
        end

        def generate_sid
          ActiveSupport::SecureRandom.hex(16)
        end

        def set_cookie(request, options)
          if request.cookie_jar[@key] != options[:value] || !options[:expires].nil?
            request.cookie_jar[@key] = options
          end
        end

        def load_session(env)
          stale_session_check! do
            if sid = current_session_id(env)
              sid, session = get_session(env, sid)
            else
              sid, session = generate_sid, {}
            end
            [sid, session]
          end
        end

        def extract_session_id(env)
          stale_session_check! do
            request = ActionDispatch::Request.new(env)
            sid = request.cookies[@key]
            sid ||= request.params[@key] unless @cookie_only
            sid
          end
        end

        def current_session_id(env)
          env[ENV_SESSION_OPTIONS_KEY][:id]
        end

        def ensure_session_key!
          if @key.blank?
            raise ArgumentError, 'A key is required to write a ' +
              'cookie containing the session data. Use ' +
              'config.session_store SESSION_STORE, { :key => ' +
              '"_myapp_session" } in config/application.rb'
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

        def exists?(env)
          current_session_id(env).present?
        end

        def get_session(env, sid)
          raise '#get_session needs to be implemented.'
        end

        def set_session(env, sid, session_data)
          raise '#set_session needs to be implemented and should return ' <<
            'the value to be stored in the cookie (usually the sid)'
        end

        def destroy(env)
          raise '#destroy needs to be implemented.'
        end
    end
  end
end
