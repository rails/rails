# frozen_string_literal: true

module ActiveJob
  module Serializers
    class ClassBasedSerializer < ObjectSerializer
      mattr_accessor :serializers, default: {}

      class << self
        def add_serializer(klass, serializer)
          self.serializers[klass] = serializer
        end
      end

      [
        SymbolSerializer.instance,
        DurationSerializer.instance,
        DateTimeSerializer.instance,
        DateSerializer.instance,
        TimeWithZoneSerializer.instance,
        TimeSerializer.instance,
        ModuleSerializer.instance,
        RangeSerializer.instance,
        BigDecimalSerializer.instance
      ].each do |serializer|
        add_serializer(serializer.klass, serializer)
      end

      def serialize?(argument)
        self.class.serializers.include?(argument.class)
      end

      def serialize(argument)
        serializer = self.class.serializers[argument.class]
        raise SerializationError, "No serializer found for #{argument.class}" unless serializer
        serializer.serialize(argument)
      end

      def deserialize(_hash)
        raise NotImplementedError, "ClassBasedSerializer is a wrapper around an array of other serializers and cannot itself be deserialized."
      end
    end
  end
end
