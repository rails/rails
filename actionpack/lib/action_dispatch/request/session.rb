require 'rack/session/abstract/id'

module ActionDispatch
  class Request < Rack::Request
    # Session is responsible for lazily loading the session from store.
    class Session # :nodoc:
      ENV_SESSION_KEY         = Rack::Session::Abstract::ENV_SESSION_KEY # :nodoc:
      ENV_SESSION_OPTIONS_KEY = Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY # :nodoc:

      attr_writer :id

      def self.create(store, env, default_options)
        session_was = find env
        session     = Request::Session.new(store, env)
        session.merge! session_was if session_was

        set(env, session)
        set_options(env, default_options.dup)
        session
      end

      def self.find(env)
        env[ENV_SESSION_KEY]
      end

      def self.set(env, session)
        env[ENV_SESSION_KEY] = session
      end

      def self.set_options(env, options)
        env[ENV_SESSION_OPTIONS_KEY] = options
      end

      def initialize(by, env)
        @by       = by
        @env      = env
        @delegate = {}
        @loaded   = false
        @exists   = nil # we haven't checked yet
      end

      def options
        @env[ENV_SESSION_OPTIONS_KEY]
      end

      def id
        return @id if @loaded or instance_variable_defined?(:@id)
        @id = @by.send(:extract_session_id, @env)
      end

      def destroy
        clear
        options = self.options || {}
        @id = @by.send(:destroy_session, @env, id, options)

        # Load the new sid to be written with the response
        @loaded = false
        load_for_write!
      end

      def [](key)
        load_for_read!
        @delegate[key.to_s]
      end

      def has_key?(key)
        load_for_read!
        @delegate.key?(key.to_s)
      end
      alias :key? :has_key?
      alias :include? :has_key?

      def keys
        @delegate.keys
      end

      def values
        @delegate.values
      end

      def []=(key, value)
        load_for_write!
        @delegate[key.to_s] = value
      end

      def clear
        load_for_write!
        @delegate.clear
      end

      def to_hash
        load_for_read!
        @delegate.dup.delete_if { |_,v| v.nil? }
      end

      def update(hash)
        load_for_write!
        @delegate.update stringify_keys(hash)
      end

      def delete(key)
        load_for_write!
        @delegate.delete key.to_s
      end

      def inspect
        if loaded?
          super
        else
          "#<#{self.class}:0x#{(object_id << 1).to_s(16)} not yet loaded>"
        end
      end

      def exists?
        return @exists unless @exists.nil?
        @exists = @by.send(:session_exists?, @env)
      end

      def loaded?
        @loaded
      end

      def empty?
        load_for_read!
        @delegate.empty?
      end

      def merge!(other)
        load_for_write!
        @delegate.merge!(other)
      end

      private

      def load_for_read!
        load! if !loaded? && exists?
      end

      def load_for_write!
        load! unless loaded?
      end

      def load!
        @id, session = @by.load_session @env
        @delegate.replace(stringify_keys(session))
        @loaded = true
      end

      def stringify_keys(other)
        other.each_with_object({}) { |(key, value), hash|
          hash[key.to_s] = value
        }
      end
    end
  end
end
