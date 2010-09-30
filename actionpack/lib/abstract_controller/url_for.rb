module AbstractController
  module UrlFor
    extend ActiveSupport::Concern
    include ActionDispatch::Routing::UrlFor

    def _routes
      raise "In order to use #url_for, you must include routing helpers explicitly. " \
            "For instance, `include Rails.application.routes.url_helpers"
    end

    module ClassMethods
      def _routes
        nil
      end

      def action_methods
        @action_methods ||= begin
          if _routes
            super - _routes.named_routes.helper_names
          else
            super
          end
        end
      end
    end
  end
end
