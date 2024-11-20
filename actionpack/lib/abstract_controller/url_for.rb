# frozen_string_literal: true

# :markup: markdown

module AbstractController
  # # URL For
  #
  # Includes `url_for` into the host class (e.g. an abstract controller or
  # mailer). The class has to provide a `RouteSet` by implementing the `_routes`
  # methods. Otherwise, an exception will be raised.
  #
  # Note that this module is completely decoupled from HTTP - the only requirement
  # is a valid `_routes` implementation.
  module UrlFor
    extend ActiveSupport::Concern
    include ActionDispatch::Routing::UrlFor

    def _routes
      raise "In order to use #url_for, you must include routing helpers explicitly. " \
            "For instance, `include Rails.application.routes.url_helpers`."
    end

    module ClassMethods
      def _routes
        nil
      end

      def action_methods
        @action_methods ||= if _routes
          super - _routes.named_routes.helper_names
        else
          super
        end
      end
    end
  end
end
