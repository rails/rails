# frozen_string_literal: true

require "rails/command"

module Rails
  module Command
    class RoutesCommand < Base # :nodoc:
      class_option :controller, aliases: "-c", desc: "Filter by a specific controller, e.g. PostsController or Admin::PostsController."
      class_option :grep, aliases: "-g", desc: "Grep routes by a specific pattern."
      class_option :search, aliases: "-s", desc: "Search route metadata for literal text."
      class_option :recognize, aliases: "-r", desc: "Find routes that recognize a request path."
      class_option :name, desc: "Filter routes by name."
      class_option :path, desc: "Filter routes by path."
      class_option :action, desc: "Filter routes by action."
      class_option :verb, desc: "Filter routes by HTTP verb."
      class_option :regex, type: :boolean, desc: "Interpret search and filter values as regular expressions."
      class_option :exact, type: :boolean, desc: "Match complete field values."
      class_option :format, enum: %w(table expanded json tsv), desc: "Choose the output format."
      class_option :expanded, type: :boolean, aliases: "-E", desc: "Print routes expanded vertically with parts explained."
      class_option :unused, type: :boolean, aliases: "-u", desc: "Print unused routes."

      class_exclusive :regex, :exact
      class_exclusive :format, :expanded

      no_commands do
        def invoke_command(*)
          if options.key?("unused")
            incompatible_options = options.keys & %w(search recognize name path action verb regex exact format expanded)
            if incompatible_options.any?
              switches = incompatible_options.map { |option| "--#{option.dasherize}" }.join(", ")
              raise Error, "The --unused option cannot be combined with #{switches}."
            end

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
      rescue RegexpError => error
        raise Error, error.message
      end

      private
        def inspector
          ActionDispatch::Routing::RoutesInspector.new(Rails.application.routes.routes)
        end

        def formatter
          format = options[:format]
          format = "expanded" if options.key?("expanded")

          case format
          when "expanded"
            ActionDispatch::Routing::ConsoleFormatter::Expanded.new
          when "json"
            ActionDispatch::Routing::ConsoleFormatter::JSON.new
          when "tsv"
            ActionDispatch::Routing::ConsoleFormatter::TSV.new
          when "table", nil
            ActionDispatch::Routing::ConsoleFormatter::Sheet.new
          end
        end

        def routes_filter
          filter = options.symbolize_keys.slice(:controller, :grep, :search, :recognize, :name, :path, :action, :verb, :regex, :exact)
          filter.delete(:grep) if filter.key?(:controller)
          filter
        end
    end
  end
end
