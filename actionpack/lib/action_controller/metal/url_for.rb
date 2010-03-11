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

    def _router
      raise "In order to use #url_for, you must include the helpers of a particular " \
            "router. For instance, `include Rails.application.routes.url_helpers"
    end
  end
end