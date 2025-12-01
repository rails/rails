# frozen_string_literal: true

module ActiveJob
  # = Active Job \Serializers
  #
  # The +ActiveJob::Serializers+ module is used to store a list of known serializers
  # and to add new ones. It also has helpers to serialize/deserialize objects.
  module Serializers # :nodoc:
    extend ActiveSupport::Autoload

    autoload :ObjectSerializer
    autoload :TimeObjectSerializer
    autoload :SymbolSerializer
    autoload :DurationSerializer
    autoload :DateTimeSerializer
    autoload :DateSerializer
    autoload :TimeWithZoneSerializer
    autoload :TimeSerializer
    autoload :ModuleSerializer
    autoload :RangeSerializer
    autoload :BigDecimalSerializer
    autoload :ActionControllerParametersSerializer

    @serializers = Set.new
    @serializers_index = {}

    class << self
      # Returns serialized representative of the passed object.
      # Will look up through all known serializers.
      # Raises ActiveJob::SerializationError if it can't find a proper serializer.
      def serialize(argument)
        serializer = @serializers_index[argument.class] || serializers.find { |s| s.serialize?(argument) }
        raise SerializationError.new("Unsupported argument type: #{argument.class.name}") unless serializer
        serializer.serialize(argument)
      end

      # Returns deserialized object.
      # Will look up through all known serializers.
      # If no serializer found will raise <tt>ArgumentError</tt>.
      def deserialize(argument)
        serializer_name = argument[OBJECT_SERIALIZER_KEY]
        raise ArgumentError, "Serializer name is not present in the argument: #{argument.inspect}" unless serializer_name

        serializer = serializer_name.safe_constantize
        raise ArgumentError, "Serializer #{serializer_name} is not known" unless serializer

        serializer.deserialize(argument)
      end

      # Returns list of known serializers.
      attr_reader :serializers

      def serializers=(serializers)
        @serializers_index.clear
        @serializers = Set.new
        add_new_serializers(serializers)
      end

      # Adds new serializers to a list of known serializers.
      def add_serializers(*new_serializers)
        new_serializers = new_serializers.flatten
        add_new_serializers(new_serializers)
      end

      private
        def add_new_serializers(new_serializers)
          new_serializers.map! do |s|
            if s.is_a?(Class) && s < ObjectSerializer
              s.instance
            else
              s
            end
          end

          @serializers += new_serializers
          index_serializers(new_serializers)
          @serializers
        end

        def index_serializers(new_serializers)
          new_serializers.each do |s|
            if s.respond_to?(:klass)
              @serializers_index[s.klass] = s
            elsif s.respond_to?(:klass, true)
              klass = s.send(:klass)
              ActiveJob.deprecator.warn(<<~MSG.squish)
                #{s.class.name}#klass method should be public.
                This will raise an error in Rails 8.2.
              MSG
              @serializers_index[klass] = s
            else
              ActiveJob.deprecator.warn(
                <<~MSG.squish
                  #{s.class.name} should implement a public #klass method.
                  This will raise an error in Rails 8.2.
                MSG
              )
            end
          end
        end
    end

    # :nodoc:
    OBJECT_SERIALIZER_KEY = "_aj_serialized"

    add_serializers SymbolSerializer.instance,
      DurationSerializer.instance,
      DateTimeSerializer.instance,
      DateSerializer.instance,
      TimeWithZoneSerializer.instance,
      TimeSerializer.instance,
      ModuleSerializer.instance,
      RangeSerializer.instance,
      BigDecimalSerializer.instance
  end
end
