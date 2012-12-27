require 'delegate'

module ActionDispatch
  module Routing
    class RouteWrapper < SimpleDelegator
      def endpoint
        rack_app ? rack_app.inspect : "#{controller}##{action}"
      end

      def constraints
        requirements.except(:controller, :action)
      end

      def rack_app(app = self.app)
        @rack_app ||= begin
          class_name = app.class.name.to_s
          if class_name == "ActionDispatch::Routing::Mapper::Constraints"
            rack_app(app.app)
          elsif ActionDispatch::Routing::Redirect === app || class_name !~ /^ActionDispatch::Routing/
            app
          end
        end
      end

      def verb
        super.source.gsub(/[$^]/, '')
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
          reqs += " #{constraints.to_s}" unless constraints.empty?
          reqs
        end
      end

      def controller
        requirements[:controller] || ':controller'
      end

      def action
        requirements[:action] || ':action'
      end

      def internal?
        controller =~ %r{\Arails/(info|welcome)} || path =~ %r{\A#{Rails.application.config.assets.prefix}}
      end

      def engine?
        rack_app && rack_app.respond_to?(:routes)
      end
    end

    ##
    # This class is just used for displaying route information when someone
    # executes `rake routes`.  People should not use this class.
    class RoutesInspector # :nodoc:
      def initialize
        @engines = Hash.new
      end

      def format(all_routes, filter = nil)
        if filter
          all_routes = all_routes.select{ |route| route.defaults[:controller] == filter }
        end

        routes = collect_routes(all_routes)

        formatted_routes(routes) +
          formatted_routes_for_engines
      end

      def collect_routes(routes)
        routes = routes.collect do |route|
          RouteWrapper.new(route)
        end.reject do |route|
          route.internal?
        end.collect do |route|
          collect_engine_routes(route)

          { name: route.name, verb: route.verb, path: route.path, reqs: route.reqs }
        end
      end

      def collect_engine_routes(route)
        name = route.endpoint
        return unless route.engine?
        return if @engines[name]

        routes = route.rack_app.routes
        if routes.is_a?(ActionDispatch::Routing::RouteSet)
          @engines[name] = collect_routes(routes.routes)
        end
      end

      def formatted_routes_for_engines
        @engines.map do |name, routes|
          ["\nRoutes for #{name}:"] + formatted_routes(routes)
        end.flatten
      end

      def formatted_routes(routes)
        name_width = routes.map{ |r| r[:name].length }.max
        verb_width = routes.map{ |r| r[:verb].length }.max
        path_width = routes.map{ |r| r[:path].length }.max

        routes.map do |r|
          "#{r[:name].rjust(name_width)} #{r[:verb].ljust(verb_width)} #{r[:path].ljust(path_width)} #{r[:reqs]}"
        end
      end
    end
  end
end
