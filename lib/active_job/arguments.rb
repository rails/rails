require 'active_model/global_locator'
require 'active_support/core_ext/object/try'

module ActiveJob
  class Arguments
    TYPE_WHITELIST = [ NilClass, Fixnum, Float, String, TrueClass, FalseClass, Bignum ]

    def self.serialize(arguments)
      arguments.collect do |argument|
        case argument
        when ActiveModel::GlobalIdentification
          argument.global_id
        when *TYPE_WHITELIST
          argument
        when Hash
          Hash[ argument.map{ |key, value| [ serialize_hash_key(key), serialize([value]).first ] } ]
        when Array
          serialize(argument)
        else
          raise "Unsupported argument type: #{argument.class.name}"
        end
      end
    end

    def self.deserialize(arguments)
      arguments.collect do |argument|
        case argument
        when Array
          deserialize(argument)
        when Hash
          Hash[argument.map{ |key, value| [ key, deserialize([value]).first ] }].with_indifferent_access
        else
          ActiveModel::GlobalLocator.locate(argument) || argument
        end
      end
    end

    private
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
