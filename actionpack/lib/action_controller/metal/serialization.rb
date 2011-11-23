module ActionController
  module Serialization
    extend ActiveSupport::Concern

    include ActionController::Renderers

    included do
      class_attribute :_serialization_scope
    end

    def serialization_scope
      send(_serialization_scope)
    end

    def _render_option_json(json, options)
      if json.respond_to?(:active_model_serializer) && (serializer = json.active_model_serializer)
        json = serializer.new(json, serialization_scope)
      end
      super
    end

    module ClassMethods
      def serialization_scope(scope)
        self._serialization_scope = scope
      end
    end
  end
end
