# frozen_string_literal: true

require 'rails/command'

module Rails
  module Command
    class RoutesCommand < Base # :nodoc:
      class_option :controller, aliases: '-c', desc: 'Filter by a specific controller, e.g. PostsController or Admin::PostsController.'
      class_option :grep, aliases: '-g', desc: 'Grep routes by a specific pattern.'
      class_option :expanded, type: :boolean, aliases: '-E', desc: 'Print routes expanded vertically with parts explained.'

      def perform(*)
        require_application_and_environment!
        require 'action_dispatch/routing/inspector'

        say inspector.format(formatter, routes_filter)
      end

      private
        def inspector
          ActionDispatch::Routing::RoutesInspector.new(Rails.application.routes.routes)
        end

        def formatter
          if options.key?('expanded')
            ActionDispatch::Routing::ConsoleFormatter::Expanded.new
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
