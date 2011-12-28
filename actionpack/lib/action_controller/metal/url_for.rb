# Includes +url_for+ into the host class. The class has to provide a +RouteSet+ by implementing 
# the <tt>_routes</tt> method. Otherwise, an exception will be raised.
#
# In addition to <tt>AbstractController::UrlFor</tt>, this module accesses the HTTP layer to define 
# url options like the +host+. In order to do so, this module requires the host class
# to implement +env+ and +request+, which need to be a Rack-compatible.
#
# Example:
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
# 
module ActionController
  module UrlFor
    extend ActiveSupport::Concern

    include AbstractController::UrlFor

    def url_options
      @_url_options ||= super.reverse_merge(
        :host => request.host,
        :port => request.optional_port,
        :protocol => request.protocol,
        :_path_segments => request.symbolized_path_parameters
      ).freeze

      if _routes.equal?(env["action_dispatch.routes"])
        @_url_options.dup.tap do |options|
          options[:script_name] = request.script_name.dup
          options.freeze
        end
      else
        @_url_options
      end
    end

  end
end
