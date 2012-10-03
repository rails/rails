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
  #     delegate :env, :request, :to => :controller
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
      @_url_options ||= super.reverse_merge(
        :host => request.host,
        :port => request.optional_port,
        :protocol => request.protocol,
        :_recall => request.symbolized_path_parameters
      ).freeze

      if (same_origin = _routes.equal?(env["action_dispatch.routes"])) ||
         (script_name = env["ROUTES_#{_routes.object_id}_SCRIPT_NAME"]) ||
         (original_script_name = env['SCRIPT_NAME'])
        @_url_options.dup.tap do |options|
          if original_script_name
            options[:original_script_name] = original_script_name
          else
            options[:script_name] = same_origin ? request.script_name.dup : script_name
          end
          options.freeze
        end
      else
        @_url_options
      end
    end
  end
end
