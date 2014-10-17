module ActiveJob
  # Raised when an exception is raised during job arguments deserialization.
  #
  # Wraps the original exception raised as +original_exception+.
  class DeserializationError < StandardError
    attr_reader :original_exception

    def initialize(e) #:nodoc:
      super("Error while trying to deserialize arguments: #{e.message}")
      @original_exception = e
      set_backtrace e.backtrace
    end
  end

  # Raised when an unsupported argument type is being set as job argument. We
  # currently support NilClass, Fixnum, Float, String, TrueClass, FalseClass,
  # Bignum and object that can be represented as GlobalIDs (ex: Active Record).
  # Also raised if you set the key for a Hash something else than a string or
  # a symbol.
  class SerializationError < ArgumentError
  end

  module Arguments
    extend self
    TYPE_WHITELIST = [ NilClass, Fixnum, Float, String, TrueClass, FalseClass, Bignum ]

    # Serializes a set of arguments. Whitelisted types are returned
    # as-is. Arrays/Hashes are serialized element by element.
    # All other types are serialized using GlobalID.
    def serialize(arguments)
      arguments.map { |argument| serialize_argument(argument) }
    end

    # Deserializes a set of arguments. Whitelisted types are returned
    # as-is. Arrays/Hashes are deserialized element by element.
    # All other types are deserialized using GlobalID.
    def deserialize(arguments)
      arguments.map { |argument| deserialize_argument(argument) }
    rescue => e
      raise DeserializationError.new(e)
    end

    private
      GLOBALID_KEY = '_aj_globalid'.freeze
      private_constant :GLOBALID_KEY

      def serialize_argument(argument)
        case argument
        when *TYPE_WHITELIST
          argument
        when GlobalID::Identification
          { GLOBALID_KEY => argument.to_global_id.to_s }
        when Array
          argument.map { |arg| serialize_argument(arg) }
        when Hash
          argument.each_with_object({}) do |(key, value), hash|
            hash[serialize_hash_key(key)] = serialize_argument(value)
          end
        else
          raise SerializationError.new("Unsupported argument type: #{argument.class.name}")
        end
      end

      def deserialize_argument(argument)
        case argument
        when String
          GlobalID::Locator.locate(argument) || argument
        when *TYPE_WHITELIST
          argument
        when Array
          argument.map { |arg| deserialize_argument(arg) }
        when Hash
          if serialized_global_id?(argument)
            deserialize_global_id argument
          else
            deserialize_hash argument
          end
        else
          raise ArgumentError, "Can only deserialize primitive arguments: #{argument.inspect}"
        end
      end

      def serialized_global_id?(hash)
        hash.size == 1 and hash.include?(GLOBALID_KEY)
      end

      def deserialize_global_id(hash)
        GlobalID::Locator.locate hash[GLOBALID_KEY]
      end

      def deserialize_hash(serialized_hash)
        serialized_hash.each_with_object({}.with_indifferent_access) do |(key, value), hash|
          hash[key] = deserialize_argument(value)
        end
      end

      RESERVED_KEYS = [GLOBALID_KEY, GLOBALID_KEY.to_sym]
      private_constant :RESERVED_KEYS

      def serialize_hash_key(key)
        case key
        when *RESERVED_KEYS
          raise SerializationError.new("Can't serialize a Hash with reserved key #{key.inspect}")
        when String, Symbol
          key.to_s
        else
          raise SerializationError.new("Only string and symbol hash keys may be serialized as job arguments, but #{key.inspect} is a #{key.class}")
        end
      end
  end
end
