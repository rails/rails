# frozen_string_literal: true

# :markup: markdown

require "rack/session/abstract/id"

module ActionDispatch
  class Request
    # Session is responsible for lazily loading the session from store.
    class Session # :nodoc:
      DisabledSessionError    = Class.new(StandardError)
      ENV_SESSION_KEY         = Rack::RACK_SESSION # :nodoc:
      ENV_SESSION_OPTIONS_KEY = Rack::RACK_SESSION_OPTIONS # :nodoc:

      # Singleton object used to determine if an optional param wasn't specified.
      Unspecified = Object.new

      # Creates a session hash, merging the properties of the previous session if any.
      def self.create(store, req, default_options)
        session_was = find req
        session     = Request::Session.new(store, req)
        session.merge! session_was if session_was

        set(req, session)
        Options.set(req, Request::Session::Options.new(store, default_options))
        session
      end

      def self.disabled(req)
        new(nil, req, enabled: false).tap do
          Session::Options.set(req, Session::Options.new(nil, { id: nil }))
        end
      end

      def self.find(req)
        req.get_header ENV_SESSION_KEY
      end

      def self.set(req, session)
        req.set_header ENV_SESSION_KEY, session
      end

      def self.delete(req)
        req.delete_header ENV_SESSION_KEY
      end

      class Options # :nodoc:
        def self.set(req, options)
          req.set_header ENV_SESSION_OPTIONS_KEY, options
        end

        def self.find(req)
          req.get_header ENV_SESSION_OPTIONS_KEY
        end

        def initialize(by, default_options)
          @by       = by
          @delegate = default_options.dup
        end

        def [](key)
          @delegate[key]
        end

        def id(req)
          @delegate.fetch(:id) {
            @by.send(:extract_session_id, req)
          }
        end

        def []=(k, v);        @delegate[k] = v; end
        def to_hash;          @delegate.dup; end
        def values_at(*args); @delegate.values_at(*args); end
      end

      def initialize(by, req, enabled: true)
        @by       = by
        @req      = req
        @delegate = {}
        @loaded   = false
        @exists   = nil # We haven't checked yet.
        @enabled  = enabled
        @id_was = nil
        @id_was_initialized = false
      end

      def id
        options.id(@req)
      end

      def enabled?
        @enabled
      end

      def options
        Options.find @req
      end

      def destroy
        clear

        if enabled?
          options = self.options || {}
          @by.send(:delete_session, @req, options.id(@req), options)

          # Load the new sid to be written with the response.
          @loaded = false
          load_for_write!
        end
      end

      # Returns value of the key stored in the session or `nil` if the given key is
      # not found in the session.
      def [](key)
        load_for_read!
        key = key.to_s

        if key == "session_id"
          id&.public_id
        else
          @delegate[key]
        end
      end

      # Returns the nested value specified by the sequence of keys, returning `nil` if
      # any intermediate step is `nil`.
      def dig(*keys)
        load_for_read!
        keys = keys.map.with_index { |key, i| i.zero? ? key.to_s : key }
        @delegate.dig(*keys)
      end

      # Returns true if the session has the given key or false.
      def has_key?(key)
        load_for_read!
        @delegate.key?(key.to_s)
      end
      alias :key? :has_key?
      alias :include? :has_key?

      # Returns keys of the session as Array.
      def keys
        load_for_read!
        @delegate.keys
      end

      # Returns values of the session as Array.
      def values
        load_for_read!
        @delegate.values
      end

      # Writes given value to given key of the session.
      def []=(key, value)
        load_for_write!
        @delegate[key.to_s] = value
      end
      alias store []=

      # Clears the session.
      def clear
        load_for_delete!
        @delegate.clear
      end

      # Returns the session as Hash.
      def to_hash
        load_for_read!
        @delegate.dup.delete_if { |_, v| v.nil? }
      end
      alias :to_h :to_hash

      # Updates the session with given Hash.
      #
      #     session.to_hash
      #     # => {"session_id"=>"e29b9ea315edf98aad94cc78c34cc9b2"}
      #
      #     session.update({ "foo" => "bar" })
      #     # => {"session_id"=>"e29b9ea315edf98aad94cc78c34cc9b2", "foo" => "bar"}
      #
      #     session.to_hash
      #     # => {"session_id"=>"e29b9ea315edf98aad94cc78c34cc9b2", "foo" => "bar"}
      def update(hash)
        unless hash.respond_to?(:to_hash)
          raise TypeError, "no implicit conversion of #{hash.class.name} into Hash"
        end

        load_for_write!
        @delegate.update hash.to_hash.stringify_keys
      end
      alias :merge! :update

      # Deletes given key from the session.
      def delete(key)
        load_for_delete!
        @delegate.delete key.to_s
      end

      # Returns value of the given key from the session, or raises `KeyError` if can't
      # find the given key and no default value is set. Returns default value if
      # specified.
      #
      #     session.fetch(:foo)
      #     # => KeyError: key not found: "foo"
      #
      #     session.fetch(:foo, :bar)
      #     # => :bar
      #
      #     session.fetch(:foo) do
      #       :bar
      #     end
      #     # => :bar
      def fetch(key, default = Unspecified, &block)
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
        return false unless enabled?
        return @exists unless @exists.nil?
        @exists = @by.send(:session_exists?, @req)
      end

      def loaded?
        @loaded
      end

      def empty?
        load_for_read!
        @delegate.empty?
      end

      def each(&block)
        to_hash.each(&block)
      end

      def id_was
        load_for_read!
        @id_was
      end

      private
        def load_for_read!
          load! if !loaded? && exists?
        end

        def load_for_write!
          if enabled?
            load! unless loaded?
          else
            raise DisabledSessionError, "Your application has sessions disabled. To write to the session you must first configure a session store"
          end
        end

        def load_for_delete!
          load! if enabled? && !loaded?
        end

        def load!
          if enabled?
            @id_was_initialized = true unless exists?
            id, session = @by.load_session @req
            options[:id] = id
            @delegate.replace(session.stringify_keys)
            @id_was = id unless @id_was_initialized
          end
          @id_was_initialized = true
          @loaded = true
        end
    end
  end
end
