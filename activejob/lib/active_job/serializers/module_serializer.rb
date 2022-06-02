# frozen_string_literal: true

module ActiveJob
  module Serializers
    class ModuleSerializer < ObjectSerializer # :nodoc:
      def serialize(constant)
        raise SerializationError, "Serializing an anonymous class is not supported" unless constant.name
        super("value" => constant.name)
      end

      def deserialize(hash)
        hash["value"].constantize
      end

      private
        def klass
          Module
        end
    end
  end
end
