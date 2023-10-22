# frozen_string_literal: true

require "bigdecimal"
require "active_support/core_ext/hash"

module ActiveJob
  # Raised when an exception is raised during job arguments deserialization.
  #
  # Wraps the original exception raised as +cause+.
  class DeserializationError < StandardError
    def initialize # :nodoc:
      super("Error while trying to deserialize arguments: #{$!.message}")
      set_backtrace $!.backtrace
    end
  end

  # Raised when an unsupported argument type is set as a job argument. We
  # currently support String, Integer, Float, NilClass, TrueClass, FalseClass,
  # BigDecimal, Symbol, Date, Time, DateTime, ActiveSupport::TimeWithZone,
  # ActiveSupport::Duration, Hash, ActiveSupport::HashWithIndifferentAccess,
  # Array, Range, or GlobalID::Identification instances, although this can be
  # extended by adding custom serializers.
  # Raised if you set the key for a Hash something else than a string or
  # a symbol. Also raised when trying to serialize an object which can't be
  # identified with a GlobalID - such as an unpersisted Active Record model.
  class SerializationError < ArgumentError; end

  module Arguments
    extend self
    # Serializes a set of arguments. Intrinsic types that can safely be
    # serialized without mutation are returned as-is. Arrays/Hashes are
    # serialized element by element. All other types are serialized using
    # GlobalID.
    def serialize(arguments)
      arguments.map { |argument| serialize_argument(argument) }
    end

    # Deserializes a set of arguments. Intrinsic types that can safely be
    # deserialized without mutation are returned as-is. Arrays/Hashes are
    # deserialized element by element. All other types are deserialized using
    # GlobalID.
    def deserialize(arguments)
      arguments.map { |argument| deserialize_argument(argument) }
    rescue
      raise DeserializationError
    end

    private
      # :nodoc:
      PERMITTED_TYPES = [ NilClass, String, Integer, Float, TrueClass, FalseClass ]
      # :nodoc:
      GLOBALID_KEY = "_aj_globalid"
      # :nodoc:
      SYMBOL_KEYS_KEY = "_aj_symbol_keys"
      # :nodoc:
      RUBY2_KEYWORDS_KEY = "_aj_ruby2_keywords"
      # :nodoc:
      WITH_INDIFFERENT_ACCESS_KEY = "_aj_hash_with_indifferent_access"
      # :nodoc:
      OBJECT_SERIALIZER_KEY = "_aj_serialized"

      # :nodoc:
      RESERVED_KEYS = [
        GLOBALID_KEY, GLOBALID_KEY.to_sym,
        SYMBOL_KEYS_KEY, SYMBOL_KEYS_KEY.to_sym,
        RUBY2_KEYWORDS_KEY, RUBY2_KEYWORDS_KEY.to_sym,
        OBJECT_SERIALIZER_KEY, OBJECT_SERIALIZER_KEY.to_sym,
        WITH_INDIFFERENT_ACCESS_KEY, WITH_INDIFFERENT_ACCESS_KEY.to_sym,
      ]
      private_constant :PERMITTED_TYPES, :RESERVED_KEYS, :GLOBALID_KEY,
        :SYMBOL_KEYS_KEY, :RUBY2_KEYWORDS_KEY, :WITH_INDIFFERENT_ACCESS_KEY

      def serialize_argument(argument)
        case argument
        when *PERMITTED_TYPES
          argument
        when GlobalID::Identification
          convert_to_global_id_hash(argument)
        when Array
          argument.map { |arg| serialize_argument(arg) }
        when ActiveSupport::HashWithIndifferentAccess
          serialize_indifferent_hash(argument)
        when Hash
          symbol_keys = argument.each_key.grep(Symbol).map!(&:to_s)
          aj_hash_key = if Hash.ruby2_keywords_hash?(argument)
            RUBY2_KEYWORDS_KEY
          else
            SYMBOL_KEYS_KEY
          end
          result = serialize_hash(argument)
          result[aj_hash_key] = symbol_keys
          result
        when -> (arg) { arg.respond_to?(:permitted?) && arg.respond_to?(:to_h) }
          serialize_indifferent_hash(argument.to_h)
        else
          if BigDecimal === argument && !ActiveJob.use_big_decimal_serializer
            ActiveJob.deprecator.warn(<<~MSG)
              Primitive serialization of BigDecimal job arguments is deprecated as it may serialize via .to_s using certain queue adapters.
              Enable config.active_job.use_big_decimal_serializer to use BigDecimalSerializer instead, which will be mandatory in Rails 7.2.

              Note that if your application has multiple replicas, you should only enable this setting after successfully deploying your app to Rails 7.1 first.
              This will ensure that during your deployment all replicas are capable of deserializing arguments serialized with BigDecimalSerializer.
            MSG
            return argument
          end

          Serializers.serialize(argument)
        end
      end

      def deserialize_argument(argument)
        case argument
        when *PERMITTED_TYPES
          argument
        when BigDecimal # BigDecimal may have been legacy serialized; Remove in 7.2
          argument
        when Array
          argument.map { |arg| deserialize_argument(arg) }
        when Hash
          if serialized_global_id?(argument)
            deserialize_global_id argument
          elsif custom_serialized?(argument)
            Serializers.deserialize(argument)
          else
            deserialize_hash(argument)
          end
        else
          raise ArgumentError, "Can only deserialize primitive arguments: #{argument.inspect}"
        end
      end

      def serialized_global_id?(hash)
        hash.size == 1 && hash.include?(GLOBALID_KEY)
      end

      def deserialize_global_id(hash)
        GlobalID::Locator.locate hash[GLOBALID_KEY]
      end

      def custom_serialized?(hash)
        hash.key?(OBJECT_SERIALIZER_KEY)
      end

      def serialize_hash(argument)
        argument.each_with_object({}) do |(key, value), hash|
          hash[serialize_hash_key(key)] = serialize_argument(value)
        end
      end

      def deserialize_hash(serialized_hash)
        result = serialized_hash.transform_values { |v| deserialize_argument(v) }
        if result.delete(WITH_INDIFFERENT_ACCESS_KEY)
          result = result.with_indifferent_access
        elsif symbol_keys = result.delete(SYMBOL_KEYS_KEY)
          result = transform_symbol_keys(result, symbol_keys)
        elsif symbol_keys = result.delete(RUBY2_KEYWORDS_KEY)
          result = transform_symbol_keys(result, symbol_keys)
          result = Hash.ruby2_keywords_hash(result)
        end
        result
      end

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

      def serialize_indifferent_hash(indifferent_hash)
        result = serialize_hash(indifferent_hash)
        result[WITH_INDIFFERENT_ACCESS_KEY] = serialize_argument(true)
        result
      end

      def transform_symbol_keys(hash, symbol_keys)
        # NOTE: HashWithIndifferentAccess#transform_keys always
        # returns stringified keys with indifferent access
        # so we call #to_h here to ensure keys are symbolized.
        hash.to_h.transform_keys do |key|
          if symbol_keys.include?(key)
            key.to_sym
          else
            key
          end
        end
      end

      def convert_to_global_id_hash(argument)
        { GLOBALID_KEY => argument.to_global_id.to_s }
      rescue URI::GID::MissingModelIdError
        raise SerializationError, "Unable to serialize #{argument.class} " \
          "without an id. (Maybe you forgot to call save?)"
      end
  end
end
