# frozen_string_literal: true

require "rails/commands/routes/routes_command"

module Rails
  module Command
    class UnusedRoutesCommand < Rails::Command::Base # :nodoc:
      hide_command!
      class_option :controller, aliases: "-c", desc: "Filter by a specific controller, e.g. PostsController or Admin::PostsController."
      class_option :grep, aliases: "-g", desc: "Grep routes by a specific pattern."

      class RouteInfo
        def initialize(route)
          requirements = route.requirements
          @controller_name = requirements[:controller]
          @action_name = requirements[:action]
          @controller_class = (@controller_name.to_s.camelize + "Controller").safe_constantize
        end

        def unused?
          controller_class_missing? || (action_missing? && template_missing?)
        end

        private
          def view_path(root)
            File.join(root.path, @controller_name, @action_name)
          end

          def controller_class_missing?
            @controller_name && @controller_class.nil?
          end

          def template_missing?
            @controller_class && @controller_class.try(:view_paths).to_a.flat_map { |path| Dir["#{view_path(path)}.*"] }.none?
          end

          def action_missing?
            @controller_class && @controller_class.instance_methods.exclude?(@action_name.to_sym)
          end
      end

      def perform(*)
        boot_application!
        require "action_dispatch/routing/inspector"

        say(inspector.format(formatter, routes_filter))

        exit(1) if routes.any?
      end

      private
        def inspector
          ActionDispatch::Routing::RoutesInspector.new(routes)
        end

        def routes
          @routes ||= begin
            routes = Rails.application.routes.routes.select do |route|
              RouteInfo.new(route).unused?
            end

            ActionDispatch::Journey::Routes.new(routes)
          end
        end

        def formatter
          ActionDispatch::Routing::ConsoleFormatter::Unused.new
        end

        def routes_filter
          options.symbolize_keys.slice(:controller, :grep)
        end
    end
  end
end
