require "rack/session/abstract/id"

module ActionDispatch
  class Request
    # Session is responsible for lazily loading the session from store.
    class Session # :nodoc:
      ENV_SESSION_KEY         = Rack::RACK_SESSION # :nodoc:
      ENV_SESSION_OPTIONS_KEY = Rack::RACK_SESSION_OPTIONS # :nodoc:

      # Singleton object used to determine if an optional param wasn't specified
      Unspecified = Object.new

      # Creates a session hash, merging the properties of the previous session if any
      def self.create(store, req, default_options)
        session_was = find req
        session     = Request::Session.new(store, req)
        session.merge! session_was if session_was

        set(req, session)
        Options.set(req, Request::Session::Options.new(store, default_options))
        session
      end

      def self.find(req)
        req.get_header ENV_SESSION_KEY
      end

      def self.set(req, session)
        req.set_header ENV_SESSION_KEY, session
      end

      class Options #:nodoc:
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

      def initialize(by, req)
        @by       = by
        @req      = req
        @delegate = {}
        @loaded   = false
        @exists   = nil # we haven't checked yet
      end

      def id
        options.id(@req)
      end

      def options
        Options.find @req
      end

      def destroy
        clear
        options = self.options || {}
        @by.send(:delete_session, @req, options.id(@req), options)

        # Load the new sid to be written with the response
        @loaded = false
        load_for_write!
      end

      # Returns value of the key stored in the session or
      # +nil+ if the given key is not found in the session.
      def [](key)
        load_for_read!
        @delegate[key.to_s]
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
        @delegate.keys
      end

      # Returns values of the session as Array.
      def values
        @delegate.values
      end

      # Writes given value to given key of the session.
      def []=(key, value)
        load_for_write!
        @delegate[key.to_s] = value
      end

      # Clears the session.
      def clear
        load_for_write!
        @delegate.clear
      end

      # Returns the session as Hash.
      def to_hash
        load_for_read!
        @delegate.dup.delete_if { |_, v| v.nil? }
      end

      # Updates the session with given Hash.
      #
      #   session.to_hash
      #   # => {"session_id"=>"e29b9ea315edf98aad94cc78c34cc9b2"}
      #
      #   session.update({ "foo" => "bar" })
      #   # => {"session_id"=>"e29b9ea315edf98aad94cc78c34cc9b2", "foo" => "bar"}
      #
      #   session.to_hash
      #   # => {"session_id"=>"e29b9ea315edf98aad94cc78c34cc9b2", "foo" => "bar"}
      def update(hash)
        load_for_write!
        @delegate.update stringify_keys(hash)
      end

      # Deletes given key from the session.
      def delete(key)
        load_for_write!
        @delegate.delete key.to_s
      end

      # Returns value of the given key from the session, or raises +KeyError+
      # if can't find the given key and no default value is set.
      # Returns default value if specified.
      #
      #   session.fetch(:foo)
      #   # => KeyError: key not found: "foo"
      #
      #   session.fetch(:foo, :bar)
      #   # => :bar
      #
      #   session.fetch(:foo) do
      #     :bar
      #   end
      #   # => :bar
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

      def merge!(other)
        load_for_write!
        @delegate.merge!(other)
      end

      def each(&block)
        to_hash.each(&block)
      end

      private

        def load_for_read!
          load! if !loaded? && exists?
        end

        def load_for_write!
          load! unless loaded?
        end

        def load!
          id, session = @by.load_session @req
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
