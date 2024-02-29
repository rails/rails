# frozen_string_literal: true

require "rails/command"

module Rails
  module Command
    class RoutesCommand < Base # :nodoc:
      class_option :controller, aliases: "-c", desc: "Filter by a specific controller, e.g. PostsController or Admin::PostsController."
      class_option :grep, aliases: "-g", desc: "Grep routes by a specific pattern."
      class_option :unused, type: :boolean, aliases: "-u", desc: "Print unused routes."
      class_option :formatter, aliases: "-f", desc: "Specify the formatter to render the routes, e.g. sheet, expanded."

      no_commands do
        def invoke_command(*)
          if options.key?("unused")
            Rails::Command.invoke "unused_routes", ARGV
          else
            super
          end
        end
      end

      desc "routes", "List all the defined routes"
      def perform(*)
        boot_application!
        require "action_dispatch/routing/inspector"

        say inspector.format(formatter, routes_filter)
      end

      private
        def inspector
          ActionDispatch::Routing::RoutesInspector.new(Rails.application.routes.routes)
        end

        def formatter
          ActionDispatch::Routing::ConsoleFormatter.registered_formatters.fetch(options["formatter"]).new
        rescue KeyError
          ActionDispatch::Routing::ConsoleFormatter::SheetFormatter.new
        end

        def routes_filter
          options.symbolize_keys.slice(:controller, :grep)
        end
    end
  end
end
