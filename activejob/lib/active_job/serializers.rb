# frozen_string_literal: true

require "set"

module ActiveJob
  # The <tt>ActiveJob::Serializers</tt> module is used to store a list of known serializers
  # and to add new ones. It also has helpers to serialize/deserialize objects.
  module Serializers # :nodoc:
    extend ActiveSupport::Autoload
    extend ActiveSupport::Concern

    autoload :ObjectSerializer
    autoload :SymbolSerializer
    autoload :DurationSerializer
    autoload :DateTimeSerializer
    autoload :DateSerializer
    autoload :TimeWithZoneSerializer
    autoload :TimeSerializer

    mattr_accessor :_additional_serializers
    self._additional_serializers = Set.new

    class << self
      # Returns serialized representative of the passed object.
      # Will look up through all known serializers.
      # Raises <tt>ActiveJob::SerializationError</tt> if it can't find a proper serializer.
      def serialize(argument)
        serializer = serializers.detect { |s| s.serialize?(argument) }
        raise SerializationError.new("Unsupported argument type: #{argument.class.name}") unless serializer
        serializer.serialize(argument)
      end

      # Returns deserialized object.
      # Will look up through all known serializers.
      # If no serializer found will raise <tt>ArgumentError</tt>.
      def deserialize(argument)
        serializer_name = argument[Arguments::OBJECT_SERIALIZER_KEY]
        raise ArgumentError, "Serializer name is not present in the argument: #{argument.inspect}" unless serializer_name

        serializer = serializer_name.safe_constantize
        raise ArgumentError, "Serializer #{serializer_name} is not know" unless serializer

        serializer.deserialize(argument)
      end

      # Returns list of known serializers.
      def serializers
        self._additional_serializers
      end

      # Adds new serializers to a list of known serializers.
      def add_serializers(*new_serializers)
        self._additional_serializers += new_serializers.flatten
      end
    end

    add_serializers SymbolSerializer,
      DurationSerializer,
      DateTimeSerializer,
      DateSerializer,
      TimeWithZoneSerializer,
      TimeSerializer
  end
end
