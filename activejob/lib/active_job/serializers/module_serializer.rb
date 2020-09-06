# frozen_string_literal: true

module ActiveJob
  module Serializers
    class ModuleSerializer < ObjectSerializer # :nodoc:
      def serialize(constant)
        super('value' => constant.name)
      end

      def deserialize(hash)
        hash['value'].constantize
      end

      private
        def klass
          Module
        end
    end
  end
end
