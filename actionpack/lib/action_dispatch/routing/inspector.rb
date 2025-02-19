# frozen_string_literal: true

# :markup: markdown

require "delegate"
require "io/console/size"

module ActionDispatch
  module Routing
    class RouteWrapper < SimpleDelegator # :nodoc:
      def matches_filter?(filter, value)
        return __getobj__.path.match(value) if filter == :exact_path_match

        value.match?(public_send(filter))
      end

      def endpoint
        case
        when app.dispatcher?
          "#{controller}##{action}"
        when rack_app.is_a?(Proc)
          "Inline handler (Proc/Lambda)"
        else
          rack_app.inspect
        end
      end

      def constraints
        requirements.except(:controller, :action)
      end

      def rack_app
        app.rack_app
      end

      def path
        super.spec.to_s
      end

      def name
        super.to_s
      end

      def reqs
        @reqs ||= begin
          reqs = endpoint
          reqs += " #{constraints}" unless constraints.empty?
          reqs
        end
      end

      def controller
        parts.include?(:controller) ? ":controller" : requirements[:controller]
      end

      def action
        parts.include?(:action) ? ":action" : requirements[:action]
      end

      def internal?
        internal
      end

      def engine?
        app.engine?
      end
    end

    ##
    # This class is just used for displaying route information when someone
    # executes `bin/rails routes` or looks at the RoutingError page. People should
    # not use this class.
    class RoutesInspector # :nodoc:
      def initialize(routes)
        @routes = wrap_routes(routes)
      end

      def format(formatter, filter = {})
        normalized_filter = normalize_filter(filter)
        filtered_routes = filter_routes(@routes, normalized_filter)

        if filtered_routes.values.all?(&:empty?)
          formatter.no_routes(@routes, filter)

          return formatter.result
        end

        filtered_routes.each do |name, routes|
          next if normalized_filter && routes.none?

          if name
            formatter.section_title "Routes for #{name}"
          end

          if formatted_routes = format_routes(routes)
            formatter.header formatted_routes
            formatter.section formatted_routes
          end
        end

        formatter.result
      end

      private
        def normalize_filter(filter)
          if filter[:controller]
            { controller: /#{filter[:controller].underscore.sub(/_?controller\z/, "")}/ }
          elsif filter[:grep]
            grep_pattern = Regexp.new(filter[:grep])
            path = URI::RFC2396_PARSER.escape(filter[:grep])
            normalized_path = ("/" + path).squeeze("/")

            {
              controller: grep_pattern,
              action: grep_pattern,
              verb: grep_pattern,
              name: grep_pattern,
              path: grep_pattern,
              exact_path_match: normalized_path,
            }
          end
        end

        def filter_routes(routes, filter)
          if filter
            routes.transform_values do |route_set|
              route_set.select do |route|
                filter.any? { |type, value| route.matches_filter?(type, value) }
              end
            end
          else
            routes
          end
        end

        def format_routes(routes)
          return unless routes.any?

          routes.collect do |route|
            { name: route.name,
              verb: route.verb,
              path: route.path,
              reqs: route.reqs,
              source_location: route.source_location }
          end
        end

        def wrap_engine_routes(route)
          name = route.endpoint
          routes = route.rack_app.routes

          if routes.is_a?(ActionDispatch::Routing::RouteSet)
            [name, wrap_routes(routes.routes)[nil]]
          else
            []
          end
        end

        def wrap_routes(routes)
          wrapped_routes = { nil => [] }

          routes
            .map { |route| RouteWrapper.new(route) }
            .reject(&:internal?)
            .each do |route|
              wrapped_routes[nil] << route

              if route.engine?
                engine, routes = wrap_engine_routes(route)

                wrapped_routes[engine] = routes
              end
            end

          wrapped_routes
        end
    end

    module ConsoleFormatter
      class Base
        def initialize
          @buffer = []
        end

        def result
          @buffer.join("\n")
        end

        def section_title(title)
        end

        def section(routes)
        end

        def header(routes)
        end

        def no_routes(routes, filter)
          @buffer <<
            if routes.values.all?(&:empty?)
              <<~MESSAGE
                You don't have any routes defined!

                Please add some routes in config/routes.rb.
              MESSAGE
            elsif filter.key?(:controller)
              "No routes were found for this controller."
            elsif filter.key?(:grep)
              "No routes were found for this grep pattern."
            end

          @buffer << "For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html."
        end
      end

      class Sheet < Base
        def section_title(title)
          if @buffer.empty?
            @buffer << "#{title}:"
          else
            @buffer << "\n#{title}:"
          end
        end

        def section(routes)
          @buffer << draw_section(routes)
        end

        def header(routes)
          @buffer << draw_header(routes)
        end

        private
          def draw_section(routes)
            header_lengths = ["Prefix", "Verb", "URI Pattern"].map(&:length)
            name_width, verb_width, path_width = widths(routes).zip(header_lengths).map(&:max)

            routes.map do |r|
              "#{r[:name].rjust(name_width)} #{r[:verb].ljust(verb_width)} #{r[:path].ljust(path_width)} #{r[:reqs]}"
            end
          end

          def draw_header(routes)
            name_width, verb_width, path_width = widths(routes)

            "#{"Prefix".rjust(name_width)} #{"Verb".ljust(verb_width)} #{"URI Pattern".ljust(path_width)} Controller#Action"
          end

          def widths(routes)
            [routes.map { |r| r[:name].length }.max || 0,
             routes.map { |r| r[:verb].length }.max || 0,
             routes.map { |r| r[:path].length }.max || 0]
          end
      end

      class Expanded < Base
        def initialize(width: IO.console_size[1])
          @width = width
          super()
        end

        def section_title(title)
          @buffer << "\n#{"[ #{title} ]"}"
        end

        def section(routes)
          @buffer << draw_expanded_section(routes)
        end

        private
          def draw_expanded_section(routes)
            routes.map.each_with_index do |r, i|
              route_rows = <<~MESSAGE.chomp
                #{route_header(index: i + 1)}
                Prefix            | #{r[:name]}
                Verb              | #{r[:verb]}
                URI               | #{r[:path]}
                Controller#Action | #{r[:reqs]}
              MESSAGE
              source_location = "\nSource Location   | #{r[:source_location]}"
              route_rows += source_location if r[:source_location].present?
              route_rows
            end
          end

          def route_header(index:)
            "--[ Route #{index} ]".ljust(@width, "-")
          end
      end

      class Unused < Sheet
        def header(routes)
          @buffer << <<~MSG
            Found #{routes.count} unused #{"route".pluralize(routes.count)}:
          MSG

          super
        end

        def no_routes(routes, filter)
          @buffer <<
            if filter.none?
              "No unused routes found."
            elsif filter.key?(:controller)
              "No unused routes found for this controller."
            elsif filter.key?(:grep)
              "No unused routes found for this grep pattern."
            end
        end
      end
    end

    class HtmlTableFormatter
      def initialize(view)
        @view = view
        @buffer = []
      end

      def section_title(title)
        @buffer << %(<tr><th colspan="5">#{title}</th></tr>)
      end

      def section(routes)
        @buffer << @view.render(partial: "routes/route", collection: routes)
      end

      # The header is part of the HTML page, so we don't construct it here.
      def header(routes)
      end

      def no_routes(*)
        @buffer << <<~MESSAGE
          <p>You don't have any routes defined!</p>
          <ul>
            <li>Please add some routes in <tt>config/routes.rb</tt>.</li>
            <li>
              For more information about routes, please see the Rails guide
              <a href="https://guides.rubyonrails.org/routing.html">Rails Routing from the Outside In</a>.
            </li>
          </ul>
        MESSAGE
      end

      def result
        @view.raw @view.render(layout: "routes/table") {
          @view.raw @buffer.join("\n")
        }
      end
    end
  end
end
