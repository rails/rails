# frozen_string_literal: true

require "active_support/core_ext/hash"

module ActiveJob
  module Arguments
    extend self
    # :nodoc:
    TYPE_WHITELIST = [ NilClass, String, Integer, Float, BigDecimal, TrueClass, FalseClass ]
    TYPE_WHITELIST.push(Fixnum, Bignum) unless 1.class == Integer

    # Serializes a set of arguments. Whitelisted types are returned
    # as-is. Arrays/Hashes are serialized element by element.
    # All other types are serialized using GlobalID.
    def serialize(arguments)
      ActiveJob::Serializers.serialize(arguments)
    end

    # Deserializes a set of arguments. Whitelisted types are returned
    # as-is. Arrays/Hashes are deserialized element by element.
    # All other types are deserialized using GlobalID.
    def deserialize(arguments)
      ActiveJob::Serializers.deserialize(arguments)
    rescue
      raise DeserializationError
    end
  end
end
