# frozen_string_literal: true

require "rails/command"

module Rails
  module Command
    class RoutesCommand < Base # :nodoc:
      class_option :controller, aliases: "-c", desc: "Filter by a specific controller, e.g. PostsController or Admin::PostsController."
      class_option :grep, aliases: "-g", desc: "Grep routes by a specific pattern."
      class_option :expanded, type: :boolean, aliases: "-E", desc: "Print routes expanded vertically with parts explained."
      class_option :separated, type: :boolean, aliases: "-s", desc: "Print routes separated by empty line between each controller routes."

      def perform(*)
        if options[:expanded] && options[:separated]
          say "WARNING: rails routes options cannot be both expanded (-E) and separated (-s).", :red
          exit 1
        end

        require_application_and_environment!
        require "action_dispatch/routing/inspector"

        say inspector.format(formatter, routes_filter)
      end

      private
        def inspector
          ActionDispatch::Routing::RoutesInspector.new(Rails.application.routes.routes)
        end

        def formatter
          if options[:expanded]
            ActionDispatch::Routing::ConsoleFormatter::Expanded.new
          elsif options[:separated]
            ActionDispatch::Routing::ConsoleFormatter::Separated.new
          else
            ActionDispatch::Routing::ConsoleFormatter::Sheet.new
          end
        end

        def routes_filter
          options.symbolize_keys.slice(:controller, :grep)
        end
    end
  end
end
