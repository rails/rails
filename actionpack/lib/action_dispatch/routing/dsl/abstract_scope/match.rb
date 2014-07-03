require 'action_dispatch/routing/dsl/abstract_scope/mapping'

module ActionDispatch
  module Routing
    module DSL
      class AbstractScope
        # Matches a url pattern to one or more routes.
        #
        # You should not use the `match` method in your router
        # without specifying an HTTP method.
        #
        # If you want to expose your action to both GET and POST, use:
        #
        #   # sets :controller, :action and :id in params
        #   match ':controller/:action/:id', via: [:get, :post]
        #
        # Note that +:controller+, +:action+ and +:id+ are interpreted as url
        # query parameters and thus available through +params+ in an action.
        #
        # If you want to expose your action to GET, use `get` in the router:
        #
        # Instead of:
        #
        #   match ":controller/:action/:id"
        #
        # Do:
        #
        #   get ":controller/:action/:id"
        #
        # Two of these symbols are special, +:controller+ maps to the controller
        # and +:action+ to the controller's action. A pattern can also map
        # wildcard segments (globs) to params:
        #
        #   get 'songs/*category/:title', to: 'songs#show'
        #
        #   # 'songs/rock/classic/stairway-to-heaven' sets
        #   #  params[:category] = 'rock/classic'
        #   #  params[:title] = 'stairway-to-heaven'
        #
        # To match a wildcard parameter, it must have a name assigned to it.
        # Without a variable name to attach the glob parameter to, the route
        # can't be parsed.
        #
        # When a pattern points to an internal route, the route's +:action+ and
        # +:controller+ should be set in options or hash shorthand. Examples:
        #
        #   match 'photos/:id' => 'photos#show', via: :get
        #   match 'photos/:id', to: 'photos#show', via: :get
        #   match 'photos/:id', controller: 'photos', action: 'show', via: :get
        #
        # A pattern can also point to a +Rack+ endpoint i.e. anything that
        # responds to +call+:
        #
        #   match 'photos/:id', to: lambda {|hash| [200, {}, ["Coming soon"]] }, via: :get
        #   match 'photos/:id', to: PhotoRackApp, via: :get
        #   # Yes, controller actions are just rack endpoints
        #   match 'photos/:id', to: PhotosController.action(:show), via: :get
        #
        # Because requesting various HTTP verbs with a single action has security
        # implications, you must either specify the actions in
        # the via options or use one of the HtttpHelpers[rdoc-ref:HttpHelpers]
        # instead +match+
        #
        # === Options
        #
        # Any options not seen here are passed on as params with the url.
        #
        # [:controller]
        #   The route's controller.
        #
        # [:action]
        #   The route's action.
        #
        # [:param]
        #   Overrides the default resource identifier `:id` (name of the
        #   dynamic segment used to generate the routes).
        #   You can access that segment from your controller using
        #   <tt>params[<:param>]</tt>.
        #
        # [:path]
        #   The path prefix for the routes.
        #
        # [:module]
        #   The namespace for :controller.
        #
        #     match 'path', to: 'c#a', module: 'sekret', controller: 'posts', via: :get
        #     # => Sekret::PostsController
        #
        #   See <tt>Scoping#namespace</tt> for its scope equivalent.
        #
        # [:as]
        #   The name used to generate routing helpers.
        #
        # [:via]
        #   Allowed HTTP verb(s) for route.
        #
        #      match 'path', to: 'c#a', via: :get
        #      match 'path', to: 'c#a', via: [:get, :post]
        #      match 'path', to: 'c#a', via: :all
        #
        # [:to]
        #   Points to a +Rack+ endpoint. Can be an object that responds to
        #   +call+ or a string representing a controller's action.
        #
        #      match 'path', to: 'controller#action', via: :get
        #      match 'path', to: lambda { |env| [200, {}, ["Success!"]] }, via: :get
        #      match 'path', to: RackApp, via: :get
        #
        # [:on]
        #   Shorthand for wrapping routes in a specific RESTful context. Valid
        #   values are +:member+, +:collection+, and +:new+. Only use within
        #   <tt>resource(s)</tt> block. For example:
        #
        #      resource :bar do
        #        match 'foo', to: 'c#a', on: :member, via: [:get, :post]
        #      end
        #
        #   Is equivalent to:
        #
        #      resource :bar do
        #        member do
        #          match 'foo', to: 'c#a', via: [:get, :post]
        #        end
        #      end
        #
        # [:constraints]
        #   Constrains parameters with a hash of regular expressions
        #   or an object that responds to <tt>matches?</tt>. In addition, constraints
        #   other than path can also be specified with any object
        #   that responds to <tt>===</tt> (eg. String, Array, Range, etc.).
        #
        #     match 'path/:id', constraints: { id: /[A-Z]\d{5}/ }, via: :get
        #
        #     match 'json_only', constraints: { format: 'json' }, via: :get
        #
        #     class Whitelist
        #       def matches?(request) request.remote_ip == '1.2.3.4' end
        #     end
        #     match 'path', to: 'c#a', constraints: Whitelist.new, via: :get
        #
        #   See <tt>Scoping#constraints</tt> for more examples with its scope
        #   equivalent.
        #
        # [:defaults]
        #   Sets defaults for parameters
        #
        #     # Sets params[:format] to 'jpg' by default
        #     match 'path', to: 'c#a', defaults: { format: 'jpg' }, via: :get
        #
        #   See <tt>Scoping#defaults</tt> for its scope equivalent.
        #
        # [:anchor]
        #   Boolean to anchor a <tt>match</tt> pattern. Default is true. When set to
        #   false, the pattern matches any request prefixed with the given path.
        #
        #     # Matches any request starting with 'path'
        #     match 'path', to: 'c#a', anchor: false, via: :get
        #
        # [:format]
        #   Allows you to specify the default value for optional +format+
        #   segment or disable it by supplying +false+.
        def match(path, *rest)
          if rest.empty? && Hash === path
            options  = path
            path, to = options.find { |name, _value| name.is_a?(String) }

            case to
            when Symbol
              options[:action] = to
            when String
              if to =~ /#/
                options[:to] = to
              else
                options[:controller] = to
              end
            else
              options[:to] = to
            end

            options.delete(path)
            paths = [path]
          else
            options = rest.pop || {}
            paths = [path] + rest
          end

          options[:anchor] = true unless options.key?(:anchor)

          if options[:on] && !VALID_ON_OPTIONS.include?(options[:on])
            raise ArgumentError, "Unknown scope #{on.inspect} given to :on"
          end

          if controller && action
            options[:to] ||= "#{controller}##{action}"
          end

          paths.each do |_path|
            route_options = options.dup
            route_options[:path] ||= _path if _path.is_a?(String)

            path_without_format = _path.to_s.sub(/\(\.:format\)$/, '')
            if using_match_shorthand?(path_without_format, route_options)
              route_options[:to] ||= path_without_format.gsub(%r{^/}, "").sub(%r{/([^/]*)$}, '#\1')
              route_options[:to].tr!("-", "_")
            end

            decomposed_match(_path, route_options)
          end
          self
        end

        def using_match_shorthand?(path, options)
          path && (options[:to] || options[:action]).nil? && path =~ %r{/[\w/]+$}
        end

        def decomposed_match(path, options) # :nodoc:
          if on = options.delete(:on)
            send(on) { decomposed_match(path, options) }
          else
            add_route(path, options)
          end
        end

        def add_route(action, options) # :nodoc:
          path = path_for_action(action, options.delete(:path))
          raise ArgumentError, "path is required" if path.blank?

          action = action.to_s.dup

          if action =~ /^[\w\-\/]+$/
            options[:action] ||= action.tr('-', '_') unless action.include?("/")
          else
            action = nil
          end

          if !options.fetch(:as, true)
            options.delete(:as)
          else
            options[:as] = name_for_action(options[:as], action)
          end

          mapping = Mapping.build(self, URI.parser.escape(path), options)
          app, conditions, requirements, defaults, as, anchor = mapping.to_route
          @set.add_route(app, conditions, requirements, defaults, as, anchor)
        end

        def path_for_action(action, path) #:nodoc:
          "#{self.path}/#{action_path(action, path)}"
        end

        def action_path(name, path = nil) #:nodoc:
          name = name.to_sym if name.is_a?(String)
          path || @scope[:path_names][name] || name.to_s
        end

      end
    end
  end
end
