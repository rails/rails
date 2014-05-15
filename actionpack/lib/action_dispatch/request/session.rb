require 'rack/session/abstract/id'

module ActionDispatch
  class Request < Rack::Request
    # Session is responsible for lazily loading the session from store.
    class Session # :nodoc:
      ENV_SESSION_KEY         = Rack::Session::Abstract::ENV_SESSION_KEY # :nodoc:
      ENV_SESSION_OPTIONS_KEY = Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY # :nodoc:

      # Singleton object used to determine if an optional param wasn't specified
      Unspecified = Object.new

      def self.create(store, env, default_options)
        session_was = find env
        session     = Request::Session.new(store, env)
        session.merge! session_was if session_was

        set(env, session)
        Options.set(env, Request::Session::Options.new(store, env, default_options))
        session
      end

      def self.find(env)
        env[ENV_SESSION_KEY]
      end

      def self.set(env, session)
        env[ENV_SESSION_KEY] = session
      end

      class Options #:nodoc:
        def self.set(env, options)
          env[ENV_SESSION_OPTIONS_KEY] = options
        end

        def self.find(env)
          env[ENV_SESSION_OPTIONS_KEY]
        end

        def initialize(by, env, default_options)
          @by       = by
          @env      = env
          @delegate = default_options.dup
        end

        def [](key)
          if key == :id
            @delegate.fetch(key) {
              @delegate[:id] = @by.send(:extract_session_id, @env)
            }
          else
            @delegate[key]
          end
        end

        def []=(k,v);         @delegate[k] = v; end
        def to_hash;          @delegate.dup; end
        def values_at(*args); @delegate.values_at(*args); end
      end

      def initialize(by, env)
        @by       = by
        @env      = env
        @delegate = {}
        @loaded   = false
        @exists   = nil # we haven't checked yet
      end

      def id
        options[:id]
      end

      def options
        Options.find @env
      end

      def destroy
        clear
        options = self.options || {}
        new_sid = @by.send(:destroy_session, @env, options[:id], options)
        options[:id] = new_sid # Reset session id with a new value or nil

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

      def fetch(key, default=Unspecified, &block)
        load_for_read!
        if default == Unspecified
          @delegate.fetch(key.to_s, &block)
        else
          @delegate.fetch(key.to_s, default, &block)
        end
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
        id, session = @by.load_session @env
        options[:id] = id
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
