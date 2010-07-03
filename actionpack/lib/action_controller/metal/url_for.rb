module ActionController
  module UrlFor
    extend ActiveSupport::Concern

    include ActionDispatch::Routing::UrlFor

    def url_options
      super.reverse_merge(
        :host => request.host_with_port,
        :protocol => request.protocol,
        :_path_segments => request.symbolized_path_parameters
      ).merge(:script_name => request.script_name)
    end

    def _routes
      raise "In order to use #url_for, you must include routing helpers explicitly. " \
            "For instance, `include Rails.application.routes.url_helpers"
    end

    module ClassMethods
      def action_methods
        @action_methods ||= begin
          super - _routes.named_routes.helper_names
        end
      end
    end
  end
end
