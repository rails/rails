# frozen_string_literal: true

# :markup: markdown

require "action_dispatch/routing/route_set"

module Rails
  class Engine
    class RouteSet < ActionDispatch::Routing::RouteSet # :nodoc:
      def initialize(config = DEFAULT_CONFIG)
        super
        named_routes.url_helpers_module.prepend(method_missing_module)
        named_routes.path_helpers_module.prepend(method_missing_module)
      end

      private
        def method_missing_module
          @method_missing_module ||= Module.new do
            private
              def method_missing(method_name, *args, &block)
                application = Rails.application
                if application && application.initialized? && application.routes_reloader.execute_unless_loaded
                  ActiveSupport.run_load_hooks(:after_routes_loaded, application)
                  public_send(method_name, *args, &block)
                else
                  super(method_name, *args, &block)
                end
              end

              def respond_to_missing?(method_name, *args)
                application = Rails.application
                if application && application.initialized? && application.routes_reloader.execute_unless_loaded
                  ActiveSupport.run_load_hooks(:after_routes_loaded, application)
                  respond_to?(method_name, *args)
                else
                  super(method_name, *args)
                end
              end
          end
        end
    end
  end
end
