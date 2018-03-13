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

        say inspector.format(formatter, routes_filter)
      end

      private
        def inspector
          ActionDispatch::Routing::RoutesInspector.new(Rails.application.routes.routes)
        end

        def formatter
          if options.key?("expanded_format")
            ActionDispatch::Routing::ConsoleFormatter::Expanded.new
          else
            ActionDispatch::Routing::ConsoleFormatter::Sheet.new
          end
        end

        def routes_filter
          options.symbolize_keys.slice(:controller, :grep_pattern)
        end
    end
  end
end
