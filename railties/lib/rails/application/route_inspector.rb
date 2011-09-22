module Rails
  class Application
    ##
    # This class is just used for displaying route information when someone
    # executes `rake routes`.  People should not use this class.
    class RouteInspector # :nodoc:
      def format all_routes, filter = nil
        if filter
          all_routes = all_routes.select{ |route| route.defaults[:controller] == filter }
        end

        routes = all_routes.collect do |route|

          reqs = route.requirements.dup
          rack_app = route.app unless route.app.class.name.to_s =~ /^ActionDispatch::Routing/

          endpoint = rack_app ? rack_app.inspect : "#{reqs[:controller]}##{reqs[:action]}"
          constraints = reqs.except(:controller, :action)

          reqs = endpoint == '#' ? '' : endpoint

          unless constraints.empty?
            reqs = reqs.empty? ? constraints.inspect : "#{reqs} #{constraints.inspect}"
          end

          verb = route.verb.source.gsub(/[$^]/, '')
          {:name => route.name.to_s, :verb => verb, :path => route.path.spec.to_s, :reqs => reqs}
        end

        # Skip the route if it's internal info route
        routes.reject! { |r| r[:path] =~ %r{/rails/info/properties|^/assets} }

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
