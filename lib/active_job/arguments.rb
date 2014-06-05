require 'active_model/global_locator'

module ActiveJob
  class Arguments
    TYPE_WHITELIST = [ NilClass, Fixnum, Float, String, TrueClass, FalseClass, Bignum ]

    def self.serialize(arguments)
      arguments.map { |argument| serialize_argument(argument) }
    end

    def self.deserialize(arguments)
      arguments.map { |argument| deserialize_argument(argument) }
    end

    private
      def self.serialize_argument(argument)
        case argument
        when ActiveModel::GlobalIdentification
          argument.global_id
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

      def self.deserialize_argument(argument)
        case argument
        when Array
          deserialize(argument)
        when Hash
          Hash[ argument.map { |key, value| [ key, deserialize_argument(value) ] } ].with_indifferent_access
        else
          ActiveModel::GlobalLocator.locate(argument) || argument
        end
      end

      def self.serialize_hash_key(key)
        case key
        when String, Symbol
          key.to_s
        else
          raise "Unsupported hash key type: #{key.class.name}"
        end
      end
  end
end
