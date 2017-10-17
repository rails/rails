# frozen_string_literal: true

module ActiveJob
  # Raised when an exception is raised during job arguments deserialization.
  #
  # Wraps the original exception raised as +cause+.
  class DeserializationError < StandardError
    def initialize #:nodoc:
      super("Error while trying to deserialize arguments: #{$!.message}")
      set_backtrace $!.backtrace
    end
  end

  # Raised when an unsupported argument type is set as a job argument. We
  # currently support NilClass, Integer, Fixnum, Float, String, TrueClass, FalseClass,
  # Bignum, BigDecimal, and objects that can be represented as GlobalIDs (ex: Active Record).
  # Raised if you set the key for a Hash something else than a string or
  # a symbol. Also raised when trying to serialize an object which can't be
  # identified with a Global ID - such as an unpersisted Active Record model.
  class SerializationError < ArgumentError; end

  # The <tt>ActiveJob::Serializers</tt> module is used to store a list of known serializers
  # and to add new ones. It also has helpers to serialize/deserialize objects
  module Serializers
    extend ActiveSupport::Autoload
    extend ActiveSupport::Concern

    autoload :ArraySerializer
    autoload :BaseSerializer
    autoload :ClassSerializer
    autoload :DurationSerializer
    autoload :GlobalIDSerializer
    autoload :HashWithIndifferentAccessSerializer
    autoload :HashSerializer
    autoload :ObjectSerializer
    autoload :StandardTypeSerializer
    autoload :StructSerializer
    autoload :SymbolSerializer

    included do
      class_attribute :_additional_serializers, instance_accessor: false, instance_predicate: false
      self._additional_serializers = []
    end

    # Includes the method to list known serializers and to add new ones
    module ClassMethods
      # Returns list of known serializers
      def serializers
        self._additional_serializers + SERIALIZERS
      end

      # Adds a new serializer to a list of known serializers
      def add_serializers(*serializers)
        check_duplicate_serializer_keys!(serializers)

        @_additional_serializers = serializers + @_additional_serializers
      end

      # Returns a list of reserved keys, which cannot be used as keys for a hash
      def reserved_serializers_keys
        serializers.select { |s| s.respond_to?(:key) }.map(&:key)
      end

      private

        def check_duplicate_serializer_keys!(serializers)
          keys_to_add = serializers.select { |s| s.respond_to?(:key) }.map(&:key)

          duplicate_keys = reserved_keys & keys_to_add

          raise ArgumentError.new("Can't add serializers because of keys duplication: #{duplicate_keys}") if duplicate_keys.any?
        end
    end

    # :nodoc:
    SERIALIZERS = [
      ::ActiveJob::Serializers::GlobalIDSerializer,
      ::ActiveJob::Serializers::DurationSerializer,
      ::ActiveJob::Serializers::StructSerializer,
      ::ActiveJob::Serializers::SymbolSerializer,
      ::ActiveJob::Serializers::ClassSerializer,
      ::ActiveJob::Serializers::StandardTypeSerializer,
      ::ActiveJob::Serializers::HashWithIndifferentAccessSerializer,
      ::ActiveJob::Serializers::HashSerializer,
      ::ActiveJob::Serializers::ArraySerializer
    ].freeze
    private_constant :SERIALIZERS

    class << self
      # Returns serialized representative of the passed object.
      # Will look up through all known serializers.
      # Raises `SerializationError` if it can't find a proper serializer.
      def serialize(argument)
        serializer = ::ActiveJob::Base.serializers.detect { |s| s.serialize?(argument) }
        raise SerializationError.new("Unsupported argument type: #{argument.class.name}") unless serializer
        serializer.serialize(argument)
      end

      # Returns deserialized object.
      # Will look up through all known serializers.
      # If no serializers found will raise `ArgumentError`
      def deserialize(argument)
        serializer = ::ActiveJob::Base.serializers.detect { |s| s.deserialize?(argument) }
        raise ArgumentError, "Can only deserialize primitive arguments: #{argument.inspect}" unless serializer
        serializer.deserialize(argument)
      end
    end
  end
end
