module ActionController
  module UrlFor
    extend ActiveSupport::Concern

    include ActionDispatch::Routing::UrlFor
    include ActionController::RackDelegation

    def merge_options(options)
      super.reverse_merge(
        :host => request.host_with_port,
        :protocol => request.protocol,
        :_path_segments => request.symbolized_path_parameters
      )
    end

    def _router
      raise "In order to use #url_for, you must include the helpers of a particular " \
            "router. For instance, `include Rails.application.routes.url_helpers"
    end
  end
end