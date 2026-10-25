# frozen_string_literal: true

# :markup: markdown

module ActionController
  # # Action Controller UrlFor
  #
  # Includes `url_for` into the host class. The class has to provide a `RouteSet`
  # by implementing the `_routes` method. Otherwise, an exception will be raised.
  #
  # In addition to AbstractController::UrlFor, this module accesses the HTTP layer
  # to define URL options like the `host`. In order to do so, this module requires
  # the host class to implement `env` which needs to be Rack-compatible, and
  # `request` which returns an ActionDispatch::Request instance.
  #
  #     class RootUrl
  #       include ActionController::UrlFor
  #       include Rails.application.routes.url_helpers
  #
  #       delegate :env, :request, to: :controller
  #
  #       def initialize(controller)
  #         @controller = controller
  #         @url        = root_path # named route from the application.
  #       end
  #     end
  module UrlFor
    extend ActiveSupport::Concern

    include AbstractController::UrlFor

    def initialize(...)
      super
      @_url_options = nil
      @_url_options_with_script_name = nil
    end

    def url_options
      @_url_options ||= {
        host: request.host,
        port: request.optional_port,
        protocol: request.protocol,
        _recall: request.path_parameters,
        **super,
      }.freeze

      if (same_origin = _routes.equal?(request.routes)) ||
         (script_name = request.engine_script_name(_routes)) ||
         (original_script_name = request.original_script_name)

        if original_script_name
          { **@_url_options, original_script_name: original_script_name }.freeze
        else
          effective_script_name = same_origin ? request.script_name : script_name

          # Memoized per script_name value, compared on every call: the
          # script name only changes around engine dispatch, but a stale
          # hash must never be served if it does.
          cached = @_url_options_with_script_name
          if cached && cached[:script_name] == effective_script_name
            cached
          else
            script_name = effective_script_name.empty? ? "" : effective_script_name.dup
            @_url_options_with_script_name = { **@_url_options, script_name: script_name }.freeze
          end
        end
      else
        @_url_options
      end
    end
  end
end
