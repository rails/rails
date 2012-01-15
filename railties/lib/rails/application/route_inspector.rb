module Rails
  class Application
    ##
    # This class is just used for displaying route information when someone
    # executes `rake routes`.  People should not use this class.
    class RouteInspector # :nodoc:
      def initialize
        @engines = ActiveSupport::OrderedHash.new
      end

      def format all_routes, filter = nil
        if filter
          all_routes = all_routes.select{ |route| route.defaults[:controller] == filter }
        end

        routes = collect_routes(all_routes)

        formatted_routes(routes) +
          formatted_routes_for_engines
      end

      def collect_routes(routes)
        routes = routes.collect do |route|
          route_reqs = route.requirements

          rack_app = discover_rack_app(route.app)

          controller = route_reqs[:controller] || ':controller'
          action     = route_reqs[:action]     || ':action'

          endpoint = rack_app ? rack_app.inspect : "#{controller}##{action}"
          constraints = route_reqs.except(:controller, :action)

          reqs = endpoint
          reqs += " #{constraints.inspect}" unless constraints.empty?

          verb = route.verb.source.gsub(/[$^]/, '')

          collect_engine_routes(reqs, rack_app)

          {:name => route.name.to_s, :verb => verb, :path => route.path.spec.to_s, :reqs => reqs }
        end

        # Skip the route if it's internal info route
        routes.reject { |r| r[:path] =~ %r{/rails/info/properties|^#{Rails.application.config.assets.prefix}} }
      end

      def collect_engine_routes(name, rack_app)
        return unless rack_app && rack_app.respond_to?(:routes)
        return if @engines[name]

        routes = rack_app.routes
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

      def discover_rack_app(app)
        class_name = app.class.name.to_s
        if class_name == "ActionDispatch::Routing::Mapper::Constraints"
          discover_rack_app(app.app)
        elsif class_name !~ /^ActionDispatch::Routing/
          app
        end
      end
    end
  end
end
