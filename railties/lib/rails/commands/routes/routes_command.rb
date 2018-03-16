# frozen_string_literal: true

require "rails/command"

module Rails
  module Command
    class RoutesCommand < Base # :nodoc:
      class_option :controller, aliases: "-c", type: :string, desc: "Specifies the controller."
      class_option :grep_pattern, aliases: "-g", type: :string, desc: "Specifies grep pattern."
      class_option :expanded_format, aliases: "--expanded", type: :string, desc: "Turn on expanded format mode."

      no_commands do
        def help
          say "Usage: Print out all defined routes in match order, with names."
          say ""
          say "Target specific controller with -c option, or grep routes using -g option"
          say "Use expanded format with --expanded option"
          say ""
        end
      end

      def perform(*)
        require_application_and_environment!
        require "action_dispatch/routing/inspector"

        all_routes = Rails.application.routes.routes
        inspector = ActionDispatch::Routing::RoutesInspector.new(all_routes)

        if options.has_key?("expanded_format")
          say inspector.format(ActionDispatch::Routing::ConsoleFormatter::Expanded.new, routes_filter)
        else
          say inspector.format(ActionDispatch::Routing::ConsoleFormatter::Sheet.new, routes_filter)
        end
      end

      private

        def routes_filter
          if options.has_key?("controller")
            { controller: options["controller"] }
          elsif options.has_key?("grep_pattern")
            options["grep_pattern"]
          else
            nil
          end
        end
    end
  end
end
