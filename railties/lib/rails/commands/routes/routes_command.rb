# frozen_string_literal: true

require "rails/command"

module Rails
  module Command
    class RoutesCommand < Base # :nodoc:
      class_option :controller, aliases: "-c", type: :string, desc: "Specifies the controller."
      class_option :grep_pattern, aliases: "-g", type: :string, desc: "Specifies grep pattern."

      no_commands do
        def help
          say "Usage: Print out all defined routes in match order, with names."
          say ""
          say "Target specific controller with -c option, or grep routes using -g option"
          say ""
        end
      end

      def perform(*)
        require_application_and_environment!
        require "action_dispatch/routing/inspector"

        all_routes = Rails.application.routes.routes
        inspector = ActionDispatch::Routing::RoutesInspector.new(all_routes)

        say inspector.format(ActionDispatch::Routing::ConsoleFormatter.new, routes_filter)
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
