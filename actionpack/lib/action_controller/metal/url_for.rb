module ActionController
  # Includes +url_for+ into the host class. The class has to provide a +RouteSet+ by implementing
  # the <tt>_routes</tt> method. Otherwise, an exception will be raised.
  #
  # In addition to <tt>AbstractController::UrlFor</tt>, this module accesses the HTTP layer to define
  # url options like the +host+. In order to do so, this module requires the host class
  # to implement +env+ and +request+, which need to be a Rack-compatible.
  #
  #   class RootUrl
  #     include ActionController::UrlFor
  #     include Rails.application.routes.url_helpers
  #
  #     delegate :env, :request, to: :controller
  #
  #     def initialize(controller)
  #       @controller = controller
  #       @url        = root_path # named route from the application.
  #     end
  #   end
  module UrlFor
    extend ActiveSupport::Concern

    include AbstractController::UrlFor

    def url_options
      @_url_options ||= {
        :host => request.host,
        :port => request.optional_port,
        :protocol => request.protocol,
        :_recall => request.path_parameters
      }.merge!(super).freeze

      if (same_origin = _routes.equal?(env["action_dispatch.routes".freeze])) ||
         (script_name = env["ROUTES_#{_routes.object_id}_SCRIPT_NAME"]) ||
         (original_script_name = env['ORIGINAL_SCRIPT_NAME'.freeze])

        options = @_url_options.dup
        if original_script_name
          options[:original_script_name] = original_script_name
        else
          options[:script_name] = same_origin ? request.script_name.dup : script_name
        end
        options.freeze
      else
        @_url_options
      end
    end
  end
end
