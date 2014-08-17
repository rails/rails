module ActiveJob
  class DeserializationError < StandardError
    attr_reader :original_exception

    def initialize(e)
      super ("Error while trying to deserialize arguments: #{e.message}")
      @original_exception = e
      set_backtrace e.backtrace
    end
  end

  module Arguments
    extend self
    TYPE_WHITELIST = [ NilClass, Fixnum, Float, String, TrueClass, FalseClass, Bignum ]

    def serialize(arguments)
      arguments.map { |argument| serialize_argument(argument) }
    end

    def deserialize(arguments)
      arguments.map { |argument| deserialize_argument(argument) }
    end

    private
      def serialize_argument(argument)
        case argument
        when GlobalID::Identification
          argument.global_id.to_s
        when *TYPE_WHITELIST
          argument
        when Array
          serialize(argument)
        when Hash
          Hash[ argument.map { |key, value| [ serialize_hash_key(key), serialize_argument(value) ] } ]
        else
          raise "Unsupported argument type: #{argument.class.name}"
        end
      end

      def deserialize_argument(argument)
        case argument
        when Array
          deserialize(argument)
        when Hash
          Hash[ argument.map { |key, value| [ key, deserialize_argument(value) ] } ].with_indifferent_access
        else
          GlobalID::Locator.locate(argument) || argument
        end
      rescue => e
        raise DeserializationError.new(e)
      end

      def serialize_hash_key(key)
        case key
        when String, Symbol
          key.to_s
        else
          raise "Unsupported hash key type: #{key.class.name}"
        end
      end
  end
end
