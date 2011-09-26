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
      json = json.active_model_serializer.new(json, serialization_scope) if json.respond_to?(:active_model_serializer)
      super
    end

    module ClassMethods
      def serialization_scope(scope)
        self._serialization_scope = scope
      end
    end
  end
end
