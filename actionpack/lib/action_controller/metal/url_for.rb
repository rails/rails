module ActionController
  module UrlFor
    extend ActiveSupport::Concern

    include AbstractController::UrlFor

    def url_options
      @_url_options ||= begin
        options = {}
        if _routes.equal?(env["action_dispatch.routes"])
          options[:script_name] = request.script_name.dup
        end

        super.merge(options).reverse_merge(
          :host => request.host_with_port,
          :protocol => request.protocol,
          :_path_segments => request.symbolized_path_parameters
        ).freeze
      end
    end
  end
end
