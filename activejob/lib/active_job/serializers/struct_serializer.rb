# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Provides methods to serialize and deserialize struct instances
    # (`Struct.new('Rectangle', :width, :height).new(12, 20)`)
    class StructSerializer < ObjectSerializer
      class << self
        def serialize(object)
          super.merge values_key => ::ActiveJob::Serializers.serialize(object.values)
        end

        def deserialize(hash)
          values = ::ActiveJob::Serializers.deserialize(hash[values_key])
          super.new(*values)
        end

        def key
          "_aj_struct"
        end

        private

        def klass
          ::Struct
        end

        def keys
          super.push values_key
        end

        def values_key
          "values"
        end
      end
    end
  end
end
