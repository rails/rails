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

    def serialize(arguments)
      arguments.map { |argument| serialize_argument(argument) }
    end

    def deserialize(arguments)
      arguments.map { |argument| deserialize_argument(argument) }
    rescue => e
      raise DeserializationError.new(e)
    end

    private
      def serialize_argument(argument)
        case argument
        when GlobalID::Identification
          argument.to_global_id.to_s
        when *TYPE_WHITELIST
          argument
        when Array
          argument.map { |arg| serialize_argument(arg) }
        when Hash
          Hash[ argument.map { |key, value| [ serialize_hash_key(key), serialize_argument(value) ] } ]
        else
          raise SerializationError.new("Unsupported argument type: #{argument.class.name}")
        end
      end

      def deserialize_argument(argument)
        case argument
        when Array
          argument.map { |arg| deserialize_argument(arg) }
        when Hash
          Hash[ argument.map { |key, value| [ key, deserialize_argument(value) ] } ].with_indifferent_access
        when String, GlobalID
          GlobalID::Locator.locate(argument) || argument
        else
          argument
        end
      end

      def serialize_hash_key(key)
        case key
        when String, Symbol
          key.to_s
        else
          raise SerializationError.new("Unsupported hash key type: #{key.class.name}")
        end
      end
  end
end
