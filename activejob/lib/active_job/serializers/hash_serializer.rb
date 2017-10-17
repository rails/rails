# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Provides methods to serialize and deserialize `Hash` (`{key: field, ...}`)
    # Only `String` or `Symbol` can be used as a key. Values will be serialized by known serializers
    class HashSerializer < BaseSerializer
      class << self
        def serialize(hash)
          symbol_keys = hash.each_key.grep(Symbol).map(&:to_s)
          result = serialize_hash(hash)
          result[key] = symbol_keys
          result
        end

        def deserialize?(argument)
          argument.is_a?(Hash) && argument[key]
        end

        def deserialize(hash)
          result = hash.transform_values { |v| ::ActiveJob::Serializers::deserialize(v) }
          symbol_keys = result.delete(key)
          transform_symbol_keys(result, symbol_keys)
        end

        def key
          "_aj_symbol_keys"
        end

        private

        def serialize_hash(hash)
          hash.each_with_object({}) do |(key, value), result|
            result[serialize_hash_key(key)] = ::ActiveJob::Serializers.serialize(value)
          end
        end

        def serialize_hash_key(key)
          raise SerializationError.new("Only string and symbol hash keys may be serialized as job arguments, but #{key.inspect} is a #{key.class}") unless [String, Symbol].include?(key.class)

          raise SerializationError.new("Can't serialize a Hash with reserved key #{key.inspect}") if ActiveJob::Base.reserved_serializers_keys.include?(key.to_s)

          key.to_s
        end

        def transform_symbol_keys(hash, symbol_keys)
          hash.transform_keys do |key|
            if symbol_keys.include?(key)
              key.to_sym
            else
              key
            end
          end
        end

        def klass
          ::Hash
        end
      end
    end
  end
end
