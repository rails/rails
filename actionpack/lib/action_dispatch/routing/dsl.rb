require 'action_dispatch/routing/dsl/scope'
require 'action_dispatch/routing/dsl/namespace_scope'
require 'action_dispatch/routing/dsl/constraints_scope'
require 'action_dispatch/routing/dsl/concerns_scope'
require 'action_dispatch/routing/dsl/resources_scope'

module ActionDispatch
  module Routing
    class Mapper
      module DSL
        # You can specify what Rails should route "/" to with the root method:
        #
        #   root to: 'pages#main'
        #
        # For options, see +match+, as +root+ uses it internally.
        #
        # You can also pass a string which will expand
        #
        #   root 'pages#main'
        #
        # You should put the root route at the top of <tt>config/routes.rb</tt>,
        # because this means it will be matched first. As this is the most popular route
        # of most Rails applications, this is beneficial.
        def root(options = {})
          match '/', { :as => :root, :via => :get }.merge!(options)
        end

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
        def match(path, options=nil)
        end

        # Mount a Rack-based application to be used within the application.
        #
        #   mount SomeRackApp, at: "some_route"
        #
        # Alternatively:
        #
        #   mount(SomeRackApp => "some_route")
        #
        # For options, see +match+, as +mount+ uses it internally.
        #
        # All mounted applications come with routing helpers to access them.
        # These are named after the class specified, so for the above example
        # the helper is either +some_rack_app_path+ or +some_rack_app_url+.
        # To customize this helper's name, use the +:as+ option:
        #
        #   mount(SomeRackApp => "some_route", as: "exciting")
        #
        # This will generate the +exciting_path+ and +exciting_url+ helpers
        # which can be used to navigate to this mounted app.
        def mount(app, options = nil)
          if options
            path = options.delete(:at)
          else
            unless Hash === app
              raise ArgumentError, "must be called with mount point"
            end

            options = app
            app, path = options.find { |k, _| k.respond_to?(:call) }
            options.delete(app) if app
          end

          raise "A rack application must be specified" unless path

          options[:as]  ||= app_name(app)
          target_as       = name_for_action(options[:as], path)
          options[:via] ||= :all

          match(path, options.merge(:to => app, :anchor => false, :format => false))

          define_generate_prefix(app, target_as)
          self
        end

        def default_url_options=(options)
          @set.default_url_options = options
        end
        alias_method :default_url_options, :default_url_options=

        def with_default_scope(scope, &block)
          scope(scope) do
            instance_exec(&block)
          end
        end

        # Query if the following named route was already defined.
        def has_named_route?(name)
          @set.named_routes.routes[name.to_sym]
        end

        private
          def app_name(app)
            return unless app.respond_to?(:routes)

            if app.respond_to?(:railtie_name)
              app.railtie_name
            else
              class_name = app.class.is_a?(Class) ? app.name : app.class.name
              ActiveSupport::Inflector.underscore(class_name).tr("/", "_")
            end
          end

          def define_generate_prefix(app, name)
            return unless app.respond_to?(:routes) && app.routes.respond_to?(:define_mounted_helper)

            _route = @set.named_routes.routes[name.to_sym]
            _routes = @set
            app.routes.define_mounted_helper(name)
            app.routes.extend Module.new {
              def mounted?; true; end
              define_method :find_script_name do |options|
                super(options) || begin
                prefix_options = options.slice(*_route.segment_keys)
                # we must actually delete prefix segment keys to avoid passing them to next url_for
                _route.segment_keys.each { |k| options.delete(k) }
                _routes.url_helpers.send("#{name}_path", prefix_options)
                end
              end
            }
          end

        # Define a route that only recognizes HTTP GET.
        # For supported arguments, see match[rdoc-ref:Base#match]
        #
        #   get 'bacon', to: 'food#bacon'
        def get(*args, &block)
          map_method(:get, args, &block)
        end

        # Define a route that only recognizes HTTP POST.
        # For supported arguments, see match[rdoc-ref:Base#match]
        #
        #   post 'bacon', to: 'food#bacon'
        def post(*args, &block)
          map_method(:post, args, &block)
        end

        # Define a route that only recognizes HTTP PATCH.
        # For supported arguments, see match[rdoc-ref:Base#match]
        #
        #   patch 'bacon', to: 'food#bacon'
        def patch(*args, &block)
          map_method(:patch, args, &block)
        end

        # Define a route that only recognizes HTTP PUT.
        # For supported arguments, see match[rdoc-ref:Base#match]
        #
        #   put 'bacon', to: 'food#bacon'
        def put(*args, &block)
          map_method(:put, args, &block)
        end

        # Define a route that only recognizes HTTP DELETE.
        # For supported arguments, see match[rdoc-ref:Base#match]
        #
        #   delete 'broccoli', to: 'food#broccoli'
        def delete(*args, &block)
          map_method(:delete, args, &block)
        end

        private
          def map_method(method, args, &block)
            options = args.extract_options!
            options[:via] = method
            match(*args, options, &block)
            self
          end
      end
    end
  end
end
