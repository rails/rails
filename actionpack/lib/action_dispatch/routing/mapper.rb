require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/string/filters'
require 'active_support/inflector'
require 'action_dispatch/routing/redirection'
require 'action_dispatch/routing/endpoint'
require 'active_support/deprecation'

module ActionDispatch
  module Routing
    class Mapper
      URL_OPTIONS = [:protocol, :subdomain, :domain, :host, :port]

      class Constraints < Endpoint #:nodoc:
        attr_reader :app, :constraints

        def initialize(app, constraints, dispatcher_p)
          # Unwrap Constraints objects.  I don't actually think it's possible
          # to pass a Constraints object to this constructor, but there were
          # multiple places that kept testing children of this object.  I
          # *think* they were just being defensive, but I have no idea.
          if app.is_a?(self.class)
            constraints += app.constraints
            app = app.app
          end

          @dispatcher = dispatcher_p

          @app, @constraints, = app, constraints
        end

        def dispatcher?; @dispatcher; end

        def matches?(req)
          @constraints.all? do |constraint|
            (constraint.respond_to?(:matches?) && constraint.matches?(req)) ||
              (constraint.respond_to?(:call) && constraint.call(*constraint_args(constraint, req)))
          end
        end

        def serve(req)
          return [ 404, {'X-Cascade' => 'pass'}, [] ] unless matches?(req)

          if dispatcher?
            @app.serve req
          else
            @app.call req.env
          end
        end

        private
          def constraint_args(constraint, request)
            constraint.arity == 1 ? [request] : [request.path_parameters, request]
          end
      end

      class Mapping #:nodoc:
        ANCHOR_CHARACTERS_REGEX = %r{\A(\\A|\^)|(\\Z|\\z|\$)\Z}
        OPTIONAL_FORMAT_REGEX = %r{(?:\(\.:format\)+|\.:format|/)\Z}

        attr_reader :requirements, :conditions, :defaults
        attr_reader :to, :default_controller, :default_action, :as, :anchor

        def self.build(scope, set, path, as, options)
          options = scope[:options].merge(options) if scope[:options]

          options.delete :only
          options.delete :except
          options.delete :shallow_path
          options.delete :shallow_prefix
          options.delete :shallow

          defaults = (scope[:defaults] || {}).merge options.delete(:defaults) || {}

          new scope, set, path, defaults, as, options
        end

        def initialize(scope, set, path, defaults, as, options)
          @requirements, @conditions = {}, {}
          @defaults = defaults
          @set = set

          @to                 = options.delete :to
          @default_controller = options.delete(:controller) || scope[:controller]
          @default_action     = options.delete(:action) || scope[:action]
          @as                 = as
          @anchor             = options.delete :anchor

          formatted = options.delete :format
          via = Array(options.delete(:via) { [] })
          options_constraints = options.delete :constraints

          path = normalize_path! path, formatted
          ast  = path_ast path
          path_params = path_params ast

          options = normalize_options!(options, formatted, path_params, ast, scope[:module])


          split_constraints(path_params, scope[:constraints]) if scope[:constraints]
          constraints = constraints(options, path_params)

          split_constraints path_params, constraints

          @blocks = blocks(options_constraints, scope[:blocks])

          if options_constraints.is_a?(Hash)
            split_constraints path_params, options_constraints
            options_constraints.each do |key, default|
              if URL_OPTIONS.include?(key) && (String === default || Integer === default)
                @defaults[key] ||= default
              end
            end
          end

          normalize_format!(formatted)

          @conditions[:path_info] = path
          @conditions[:parsed_path_info] = ast

          add_request_method(via, @conditions)
          normalize_defaults!(options)
        end

        def to_route
          [ app(@blocks), conditions, requirements, defaults, as, anchor ]
        end

        private

          def normalize_path!(path, format)
            path = Mapper.normalize_path(path)

            if format == true
              "#{path}.:format"
            elsif optional_format?(path, format)
              "#{path}(.:format)"
            else
              path
            end
          end

          def optional_format?(path, format)
            format != false && path !~ OPTIONAL_FORMAT_REGEX
          end

          def normalize_options!(options, formatted, path_params, path_ast, modyoule)
            # Add a constraint for wildcard route to make it non-greedy and match the
            # optional format part of the route by default
            if formatted != false
              path_ast.grep(Journey::Nodes::Star) do |node|
                options[node.name.to_sym] ||= /.+?/
              end
            end

            if path_params.include?(:controller)
              raise ArgumentError, ":controller segment is not allowed within a namespace block" if modyoule

              # Add a default constraint for :controller path segments that matches namespaced
              # controllers with default routes like :controller/:action/:id(.:format), e.g:
              # GET /admin/products/show/1
              # => { controller: 'admin/products', action: 'show', id: '1' }
              options[:controller] ||= /.+?/
            end

            if to.respond_to? :call
              options
            else
              to_endpoint = split_to to
              controller  = to_endpoint[0] || default_controller
              action      = to_endpoint[1] || default_action

              controller = add_controller_module(controller, modyoule)

              options.merge! check_controller_and_action(path_params, controller, action)
            end
          end

          def split_constraints(path_params, constraints)
            constraints.each_pair do |key, requirement|
              if path_params.include?(key) || key == :controller
                verify_regexp_requirement(requirement) if requirement.is_a?(Regexp)
                @requirements[key] = requirement
              else
                @conditions[key] = requirement
              end
            end
          end

          def normalize_format!(formatted)
            if formatted == true
              @requirements[:format] ||= /.+/
            elsif Regexp === formatted
              @requirements[:format] = formatted
              @defaults[:format] = nil
            elsif String === formatted
              @requirements[:format] = Regexp.compile(formatted)
              @defaults[:format] = formatted
            end
          end

          def verify_regexp_requirement(requirement)
            if requirement.source =~ ANCHOR_CHARACTERS_REGEX
              raise ArgumentError, "Regexp anchor characters are not allowed in routing requirements: #{requirement.inspect}"
            end

            if requirement.multiline?
              raise ArgumentError, "Regexp multiline option is not allowed in routing requirements: #{requirement.inspect}"
            end
          end

          def normalize_defaults!(options)
            options.each_pair do |key, default|
              unless Regexp === default
                @defaults[key] = default
              end
            end
          end

          def verify_callable_constraint(callable_constraint)
            unless callable_constraint.respond_to?(:call) || callable_constraint.respond_to?(:matches?)
              raise ArgumentError, "Invalid constraint: #{callable_constraint.inspect} must respond to :call or :matches?"
            end
          end

          def add_request_method(via, conditions)
            return if via == [:all]

            if via.empty?
              msg = "You should not use the `match` method in your router without specifying an HTTP method.\n" \
                    "If you want to expose your action to both GET and POST, add `via: [:get, :post]` option.\n" \
                    "If you want to expose your action to GET, use `get` in the router:\n" \
                    "  Instead of: match \"controller#action\"\n" \
                    "  Do: get \"controller#action\""
              raise ArgumentError, msg
            end

            conditions[:request_method] = via.map { |m| m.to_s.dasherize.upcase }
          end

          def app(blocks)
            if to.respond_to?(:call)
              Constraints.new(to, blocks, false)
            elsif blocks.any?
              Constraints.new(dispatcher(defaults), blocks, true)
            else
              dispatcher(defaults)
            end
          end

          def check_controller_and_action(path_params, controller, action)
            hash = check_part(:controller, controller, path_params, {}) do |part|
              translate_controller(part) {
                message = "'#{part}' is not a supported controller name. This can lead to potential routing problems."
                message << " See http://guides.rubyonrails.org/routing.html#specifying-a-controller-to-use"

                raise ArgumentError, message
              }
            end

            check_part(:action, action, path_params, hash) { |part|
              part.is_a?(Regexp) ? part : part.to_s
            }
          end

          def check_part(name, part, path_params, hash)
            if part
              hash[name] = yield(part)
            else
              unless path_params.include?(name)
                message = "Missing :#{name} key on routes definition, please check your routes."
                raise ArgumentError, message
              end
            end
            hash
          end

          def split_to(to)
            case to
            when Symbol
              ActiveSupport::Deprecation.warn(<<-MSG.squish)
                Defining a route where `to` is a symbol is deprecated.
                Please change `to: :#{to}` to `action: :#{to}`.
              MSG

              [nil, to.to_s]
            when /#/    then to.split('#')
            when String
              ActiveSupport::Deprecation.warn(<<-MSG.squish)
                Defining a route where `to` is a controller without an action is deprecated.
                Please change `to: '#{to}'` to `controller: '#{to}'`.
              MSG

              [to, nil]
            else
              []
            end
          end

          def add_controller_module(controller, modyoule)
            if modyoule && !controller.is_a?(Regexp)
              if controller =~ %r{\A/}
                controller[1..-1]
              else
                [modyoule, controller].compact.join("/")
              end
            else
              controller
            end
          end

          def translate_controller(controller)
            return controller if Regexp === controller
            return controller.to_s if controller =~ /\A[a-z_0-9][a-z_0-9\/]*\z/

            yield
          end

          def blocks(options_constraints, scope_blocks)
            if options_constraints && !options_constraints.is_a?(Hash)
              verify_callable_constraint(options_constraints)
              [options_constraints]
            else
              scope_blocks || []
            end
          end

          def constraints(options, path_params)
            constraints = {}
            required_defaults = []
            options.each_pair do |key, option|
              if Regexp === option
                constraints[key] = option
              else
                required_defaults << key unless path_params.include?(key)
              end
            end
            @conditions[:required_defaults] = required_defaults
            constraints
          end

          def path_params(ast)
            ast.grep(Journey::Nodes::Symbol).map { |n| n.name.to_sym }
          end

          def path_ast(path)
            parser = Journey::Parser.new
            parser.parse path
          end

          def dispatcher(defaults)
            @set.dispatcher defaults
          end
      end

      # Invokes Journey::Router::Utils.normalize_path and ensure that
      # (:locale) becomes (/:locale) instead of /(:locale). Except
      # for root cases, where the latter is the correct one.
      def self.normalize_path(path)
        path = Journey::Router::Utils.normalize_path(path)
        path.gsub!(%r{/(\(+)/?}, '\1/') unless path =~ %r{^/\(+[^)]+\)$}
        path
      end

      def self.normalize_name(name)
        normalize_path(name)[1..-1].tr("/", "_")
      end

      module Base
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
        # You should not use the +match+ method in your router
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
        # If you want to expose your action to GET, use +get+ in the router:
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
        # the via options or use one of the HttpHelpers[rdoc-ref:HttpHelpers]
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
        #   Overrides the default resource identifier +:id+ (name of the
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

          rails_app = rails_app? app
          options[:as] ||= app_name(app, rails_app)

          target_as       = name_for_action(options[:as], path)
          options[:via] ||= :all

          match(path, options.merge(:to => app, :anchor => false, :format => false))

          define_generate_prefix(app, target_as) if rails_app
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
          def rails_app?(app)
            app.is_a?(Class) && app < Rails::Railtie
          end

          def app_name(app, rails_app)
            if rails_app
              app.railtie_name
            elsif app.is_a?(Class)
              class_name = app.name
              ActiveSupport::Inflector.underscore(class_name).tr("/", "_")
            end
          end

          def define_generate_prefix(app, name)
            _route = @set.named_routes.get name
            _routes = @set
            app.routes.define_mounted_helper(name)
            app.routes.extend Module.new {
              def optimize_routes_generation?; false; end
              define_method :find_script_name do |options|
                if options.key? :script_name
                  super(options)
                else
                  prefix_options = options.slice(*_route.segment_keys)
                  prefix_options[:relative_url_root] = ''.freeze
                  # we must actually delete prefix segment keys to avoid passing them to next url_for
                  _route.segment_keys.each { |k| options.delete(k) }
                  _routes.url_helpers.send("#{name}_path", prefix_options)
                end
              end
            }
          end
      end

      module HttpHelpers
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

      # You may wish to organize groups of controllers under a namespace.
      # Most commonly, you might group a number of administrative controllers
      # under an +admin+ namespace. You would place these controllers under
      # the <tt>app/controllers/admin</tt> directory, and you can group them
      # together in your router:
      #
      #   namespace "admin" do
      #     resources :posts, :comments
      #   end
      #
      # This will create a number of routes for each of the posts and comments
      # controller. For <tt>Admin::PostsController</tt>, Rails will create:
      #
      #   GET       /admin/posts
      #   GET       /admin/posts/new
      #   POST      /admin/posts
      #   GET       /admin/posts/1
      #   GET       /admin/posts/1/edit
      #   PATCH/PUT /admin/posts/1
      #   DELETE    /admin/posts/1
      #
      # If you want to route /posts (without the prefix /admin) to
      # <tt>Admin::PostsController</tt>, you could use
      #
      #   scope module: "admin" do
      #     resources :posts
      #   end
      #
      # or, for a single case
      #
      #   resources :posts, module: "admin"
      #
      # If you want to route /admin/posts to +PostsController+
      # (without the <tt>Admin::</tt> module prefix), you could use
      #
      #   scope "/admin" do
      #     resources :posts
      #   end
      #
      # or, for a single case
      #
      #   resources :posts, path: "/admin/posts"
      #
      # In each of these cases, the named routes remain the same as if you did
      # not use scope. In the last case, the following paths map to
      # +PostsController+:
      #
      #   GET       /admin/posts
      #   GET       /admin/posts/new
      #   POST      /admin/posts
      #   GET       /admin/posts/1
      #   GET       /admin/posts/1/edit
      #   PATCH/PUT /admin/posts/1
      #   DELETE    /admin/posts/1
      module Scoping
        # Scopes a set of routes to the given default options.
        #
        # Take the following route definition as an example:
        #
        #   scope path: ":account_id", as: "account" do
        #     resources :projects
        #   end
        #
        # This generates helpers such as +account_projects_path+, just like +resources+ does.
        # The difference here being that the routes generated are like /:account_id/projects,
        # rather than /accounts/:account_id/projects.
        #
        # === Options
        #
        # Takes same options as <tt>Base#match</tt> and <tt>Resources#resources</tt>.
        #
        #   # route /posts (without the prefix /admin) to <tt>Admin::PostsController</tt>
        #   scope module: "admin" do
        #     resources :posts
        #   end
        #
        #   # prefix the posts resource's requests with '/admin'
        #   scope path: "/admin" do
        #     resources :posts
        #   end
        #
        #   # prefix the routing helper name: +sekret_posts_path+ instead of +posts_path+
        #   scope as: "sekret" do
        #     resources :posts
        #   end
        def scope(*args)
          options = args.extract_options!.dup
          scope = {}

          options[:path] = args.flatten.join('/') if args.any?
          options[:constraints] ||= {}

          unless nested_scope?
            options[:shallow_path] ||= options[:path] if options.key?(:path)
            options[:shallow_prefix] ||= options[:as] if options.key?(:as)
          end

          if options[:constraints].is_a?(Hash)
            defaults = options[:constraints].select do |k, v|
              URL_OPTIONS.include?(k) && (v.is_a?(String) || v.is_a?(Integer))
            end

            (options[:defaults] ||= {}).reverse_merge!(defaults)
          else
            block, options[:constraints] = options[:constraints], {}
          end

          @scope.options.each do |option|
            if option == :blocks
              value = block
            elsif option == :options
              value = options
            else
              value = options.delete(option)
            end

            if value
              scope[option] = send("merge_#{option}_scope", @scope[option], value)
            end
          end

          @scope = @scope.new scope
          yield
          self
        ensure
          @scope = @scope.parent
        end

        # Scopes routes to a specific controller
        #
        #   controller "food" do
        #     match "bacon", action: "bacon"
        #   end
        def controller(controller, options={})
          options[:controller] = controller
          scope(options) { yield }
        end

        # Scopes routes to a specific namespace. For example:
        #
        #   namespace :admin do
        #     resources :posts
        #   end
        #
        # This generates the following routes:
        #
        #       admin_posts GET       /admin/posts(.:format)          admin/posts#index
        #       admin_posts POST      /admin/posts(.:format)          admin/posts#create
        #    new_admin_post GET       /admin/posts/new(.:format)      admin/posts#new
        #   edit_admin_post GET       /admin/posts/:id/edit(.:format) admin/posts#edit
        #        admin_post GET       /admin/posts/:id(.:format)      admin/posts#show
        #        admin_post PATCH/PUT /admin/posts/:id(.:format)      admin/posts#update
        #        admin_post DELETE    /admin/posts/:id(.:format)      admin/posts#destroy
        #
        # === Options
        #
        # The +:path+, +:as+, +:module+, +:shallow_path+ and +:shallow_prefix+
        # options all default to the name of the namespace.
        #
        # For options, see <tt>Base#match</tt>. For +:shallow_path+ option, see
        # <tt>Resources#resources</tt>.
        #
        #   # accessible through /sekret/posts rather than /admin/posts
        #   namespace :admin, path: "sekret" do
        #     resources :posts
        #   end
        #
        #   # maps to <tt>Sekret::PostsController</tt> rather than <tt>Admin::PostsController</tt>
        #   namespace :admin, module: "sekret" do
        #     resources :posts
        #   end
        #
        #   # generates +sekret_posts_path+ rather than +admin_posts_path+
        #   namespace :admin, as: "sekret" do
        #     resources :posts
        #   end
        def namespace(path, options = {})
          path = path.to_s

          defaults = {
            module:         path,
            path:           options.fetch(:path, path),
            as:             options.fetch(:as, path),
            shallow_path:   options.fetch(:path, path),
            shallow_prefix: options.fetch(:as, path)
          }

          scope(defaults.merge!(options)) { yield }
        end

        # === Parameter Restriction
        # Allows you to constrain the nested routes based on a set of rules.
        # For instance, in order to change the routes to allow for a dot character in the +id+ parameter:
        #
        #   constraints(id: /\d+\.\d+/) do
        #     resources :posts
        #   end
        #
        # Now routes such as +/posts/1+ will no longer be valid, but +/posts/1.1+ will be.
        # The +id+ parameter must match the constraint passed in for this example.
        #
        # You may use this to also restrict other parameters:
        #
        #   resources :posts do
        #     constraints(post_id: /\d+\.\d+/) do
        #       resources :comments
        #     end
        #   end
        #
        # === Restricting based on IP
        #
        # Routes can also be constrained to an IP or a certain range of IP addresses:
        #
        #   constraints(ip: /192\.168\.\d+\.\d+/) do
        #     resources :posts
        #   end
        #
        # Any user connecting from the 192.168.* range will be able to see this resource,
        # where as any user connecting outside of this range will be told there is no such route.
        #
        # === Dynamic request matching
        #
        # Requests to routes can be constrained based on specific criteria:
        #
        #    constraints(lambda { |req| req.env["HTTP_USER_AGENT"] =~ /iPhone/ }) do
        #      resources :iphones
        #    end
        #
        # You are able to move this logic out into a class if it is too complex for routes.
        # This class must have a +matches?+ method defined on it which either returns +true+
        # if the user should be given access to that route, or +false+ if the user should not.
        #
        #    class Iphone
        #      def self.matches?(request)
        #        request.env["HTTP_USER_AGENT"] =~ /iPhone/
        #      end
        #    end
        #
        # An expected place for this code would be +lib/constraints+.
        #
        # This class is then used like this:
        #
        #    constraints(Iphone) do
        #      resources :iphones
        #    end
        def constraints(constraints = {})
          scope(:constraints => constraints) { yield }
        end

        # Allows you to set default parameters for a route, such as this:
        #   defaults id: 'home' do
        #     match 'scoped_pages/(:id)', to: 'pages#show'
        #   end
        # Using this, the +:id+ parameter here will default to 'home'.
        def defaults(defaults = {})
          scope(:defaults => defaults) { yield }
        end

        private
          def merge_path_scope(parent, child) #:nodoc:
            Mapper.normalize_path("#{parent}/#{child}")
          end

          def merge_shallow_path_scope(parent, child) #:nodoc:
            Mapper.normalize_path("#{parent}/#{child}")
          end

          def merge_as_scope(parent, child) #:nodoc:
            parent ? "#{parent}_#{child}" : child
          end

          def merge_shallow_prefix_scope(parent, child) #:nodoc:
            parent ? "#{parent}_#{child}" : child
          end

          def merge_module_scope(parent, child) #:nodoc:
            parent ? "#{parent}/#{child}" : child
          end

          def merge_controller_scope(parent, child) #:nodoc:
            child
          end

          def merge_action_scope(parent, child) #:nodoc:
            child
          end

          def merge_path_names_scope(parent, child) #:nodoc:
            merge_options_scope(parent, child)
          end

          def merge_constraints_scope(parent, child) #:nodoc:
            merge_options_scope(parent, child)
          end

          def merge_defaults_scope(parent, child) #:nodoc:
            merge_options_scope(parent, child)
          end

          def merge_blocks_scope(parent, child) #:nodoc:
            merged = parent ? parent.dup : []
            merged << child if child
            merged
          end

          def merge_options_scope(parent, child) #:nodoc:
            (parent || {}).except(*override_keys(child)).merge!(child)
          end

          def merge_shallow_scope(parent, child) #:nodoc:
            child ? true : false
          end

          def override_keys(child) #:nodoc:
            child.key?(:only) || child.key?(:except) ? [:only, :except] : []
          end
      end

      # Resource routing allows you to quickly declare all of the common routes
      # for a given resourceful controller. Instead of declaring separate routes
      # for your +index+, +show+, +new+, +edit+, +create+, +update+ and +destroy+
      # actions, a resourceful route declares them in a single line of code:
      #
      #  resources :photos
      #
      # Sometimes, you have a resource that clients always look up without
      # referencing an ID. A common example, /profile always shows the profile of
      # the currently logged in user. In this case, you can use a singular resource
      # to map /profile (rather than /profile/:id) to the show action.
      #
      #  resource :profile
      #
      # It's common to have resources that are logically children of other
      # resources:
      #
      #   resources :magazines do
      #     resources :ads
      #   end
      #
      # You may wish to organize groups of controllers under a namespace. Most
      # commonly, you might group a number of administrative controllers under
      # an +admin+ namespace. You would place these controllers under the
      # <tt>app/controllers/admin</tt> directory, and you can group them together
      # in your router:
      #
      #   namespace "admin" do
      #     resources :posts, :comments
      #   end
      #
      # By default the +:id+ parameter doesn't accept dots. If you need to
      # use dots as part of the +:id+ parameter add a constraint which
      # overrides this restriction, e.g:
      #
      #   resources :articles, id: /[^\/]+/
      #
      # This allows any character other than a slash as part of your +:id+.
      #
      module Resources
        # CANONICAL_ACTIONS holds all actions that does not need a prefix or
        # a path appended since they fit properly in their scope level.
        VALID_ON_OPTIONS  = [:new, :collection, :member]
        RESOURCE_OPTIONS  = [:as, :controller, :path, :only, :except, :param, :concerns]
        CANONICAL_ACTIONS = %w(index create new show update destroy)

        class Resource #:nodoc:
          attr_reader :controller, :path, :options, :param

          def initialize(entities, options = {})
            @name       = entities.to_s
            @path       = (options[:path] || @name).to_s
            @controller = (options[:controller] || @name).to_s
            @as         = options[:as]
            @param      = (options[:param] || :id).to_sym
            @options    = options
            @shallow    = false
          end

          def default_actions
            [:index, :create, :new, :show, :update, :destroy, :edit]
          end

          def actions
            if only = @options[:only]
              Array(only).map(&:to_sym)
            elsif except = @options[:except]
              default_actions - Array(except).map(&:to_sym)
            else
              default_actions
            end
          end

          def name
            @as || @name
          end

          def plural
            @plural ||= name.to_s
          end

          def singular
            @singular ||= name.to_s.singularize
          end

          alias :member_name :singular

          # Checks for uncountable plurals, and appends "_index" if the plural
          # and singular form are the same.
          def collection_name
            singular == plural ? "#{plural}_index" : plural
          end

          def resource_scope
            { :controller => controller }
          end

          alias :collection_scope :path

          def member_scope
            "#{path}/:#{param}"
          end

          alias :shallow_scope :member_scope

          def new_scope(new_path)
            "#{path}/#{new_path}"
          end

          def nested_param
            :"#{singular}_#{param}"
          end

          def nested_scope
            "#{path}/:#{nested_param}"
          end

          def shallow=(value)
            @shallow = value
          end

          def shallow?
            @shallow
          end
        end

        class SingletonResource < Resource #:nodoc:
          def initialize(entities, options)
            super
            @as         = nil
            @controller = (options[:controller] || plural).to_s
            @as         = options[:as]
          end

          def default_actions
            [:show, :create, :update, :destroy, :new, :edit]
          end

          def plural
            @plural ||= name.to_s.pluralize
          end

          def singular
            @singular ||= name.to_s
          end

          alias :member_name :singular
          alias :collection_name :singular

          alias :member_scope :path
          alias :nested_scope :path
        end

        def resources_path_names(options)
          @scope[:path_names].merge!(options)
        end

        # Sometimes, you have a resource that clients always look up without
        # referencing an ID. A common example, /profile always shows the
        # profile of the currently logged in user. In this case, you can use
        # a singular resource to map /profile (rather than /profile/:id) to
        # the show action:
        #
        #   resource :profile
        #
        # creates six different routes in your application, all mapping to
        # the +Profiles+ controller (note that the controller is named after
        # the plural):
        #
        #   GET       /profile/new
        #   POST      /profile
        #   GET       /profile
        #   GET       /profile/edit
        #   PATCH/PUT /profile
        #   DELETE    /profile
        #
        # === Options
        # Takes same options as +resources+.
        def resource(*resources, &block)
          options = resources.extract_options!.dup

          if apply_common_behavior_for(:resource, resources, options, &block)
            return self
          end

          resource_scope(:resource, SingletonResource.new(resources.pop, options)) do
            yield if block_given?

            concerns(options[:concerns]) if options[:concerns]

            collection do
              post :create
            end if parent_resource.actions.include?(:create)

            new do
              get :new
            end if parent_resource.actions.include?(:new)

            set_member_mappings_for_resource
          end

          self
        end

        # In Rails, a resourceful route provides a mapping between HTTP verbs
        # and URLs and controller actions. By convention, each action also maps
        # to particular CRUD operations in a database. A single entry in the
        # routing file, such as
        #
        #   resources :photos
        #
        # creates seven different routes in your application, all mapping to
        # the +Photos+ controller:
        #
        #   GET       /photos
        #   GET       /photos/new
        #   POST      /photos
        #   GET       /photos/:id
        #   GET       /photos/:id/edit
        #   PATCH/PUT /photos/:id
        #   DELETE    /photos/:id
        #
        # Resources can also be nested infinitely by using this block syntax:
        #
        #   resources :photos do
        #     resources :comments
        #   end
        #
        # This generates the following comments routes:
        #
        #   GET       /photos/:photo_id/comments
        #   GET       /photos/:photo_id/comments/new
        #   POST      /photos/:photo_id/comments
        #   GET       /photos/:photo_id/comments/:id
        #   GET       /photos/:photo_id/comments/:id/edit
        #   PATCH/PUT /photos/:photo_id/comments/:id
        #   DELETE    /photos/:photo_id/comments/:id
        #
        # === Options
        # Takes same options as <tt>Base#match</tt> as well as:
        #
        # [:path_names]
        #   Allows you to change the segment component of the +edit+ and +new+ actions.
        #   Actions not specified are not changed.
        #
        #     resources :posts, path_names: { new: "brand_new" }
        #
        #   The above example will now change /posts/new to /posts/brand_new
        #
        # [:path]
        #   Allows you to change the path prefix for the resource.
        #
        #     resources :posts, path: 'postings'
        #
        #   The resource and all segments will now route to /postings instead of /posts
        #
        # [:only]
        #   Only generate routes for the given actions.
        #
        #     resources :cows, only: :show
        #     resources :cows, only: [:show, :index]
        #
        # [:except]
        #   Generate all routes except for the given actions.
        #
        #     resources :cows, except: :show
        #     resources :cows, except: [:show, :index]
        #
        # [:shallow]
        #   Generates shallow routes for nested resource(s). When placed on a parent resource,
        #   generates shallow routes for all nested resources.
        #
        #     resources :posts, shallow: true do
        #       resources :comments
        #     end
        #
        #   Is the same as:
        #
        #     resources :posts do
        #       resources :comments, except: [:show, :edit, :update, :destroy]
        #     end
        #     resources :comments, only: [:show, :edit, :update, :destroy]
        #
        #   This allows URLs for resources that otherwise would be deeply nested such
        #   as a comment on a blog post like <tt>/posts/a-long-permalink/comments/1234</tt>
        #   to be shortened to just <tt>/comments/1234</tt>.
        #
        # [:shallow_path]
        #   Prefixes nested shallow routes with the specified path.
        #
        #     scope shallow_path: "sekret" do
        #       resources :posts do
        #         resources :comments, shallow: true
        #       end
        #     end
        #
        #   The +comments+ resource here will have the following routes generated for it:
        #
        #     post_comments    GET       /posts/:post_id/comments(.:format)
        #     post_comments    POST      /posts/:post_id/comments(.:format)
        #     new_post_comment GET       /posts/:post_id/comments/new(.:format)
        #     edit_comment     GET       /sekret/comments/:id/edit(.:format)
        #     comment          GET       /sekret/comments/:id(.:format)
        #     comment          PATCH/PUT /sekret/comments/:id(.:format)
        #     comment          DELETE    /sekret/comments/:id(.:format)
        #
        # [:shallow_prefix]
        #   Prefixes nested shallow route names with specified prefix.
        #
        #     scope shallow_prefix: "sekret" do
        #       resources :posts do
        #         resources :comments, shallow: true
        #       end
        #     end
        #
        #   The +comments+ resource here will have the following routes generated for it:
        #
        #     post_comments           GET       /posts/:post_id/comments(.:format)
        #     post_comments           POST      /posts/:post_id/comments(.:format)
        #     new_post_comment        GET       /posts/:post_id/comments/new(.:format)
        #     edit_sekret_comment     GET       /comments/:id/edit(.:format)
        #     sekret_comment          GET       /comments/:id(.:format)
        #     sekret_comment          PATCH/PUT /comments/:id(.:format)
        #     sekret_comment          DELETE    /comments/:id(.:format)
        #
        # [:format]
        #   Allows you to specify the default value for optional +format+
        #   segment or disable it by supplying +false+.
        #
        # === Examples
        #
        #   # routes call <tt>Admin::PostsController</tt>
        #   resources :posts, module: "admin"
        #
        #   # resource actions are at /admin/posts.
        #   resources :posts, path: "admin/posts"
        def resources(*resources, &block)
          options = resources.extract_options!.dup

          if apply_common_behavior_for(:resources, resources, options, &block)
            return self
          end

          resource_scope(:resources, Resource.new(resources.pop, options)) do
            yield if block_given?

            concerns(options[:concerns]) if options[:concerns]

            collection do
              get  :index if parent_resource.actions.include?(:index)
              post :create if parent_resource.actions.include?(:create)
            end

            new do
              get :new
            end if parent_resource.actions.include?(:new)

            set_member_mappings_for_resource
          end

          self
        end

        # To add a route to the collection:
        #
        #   resources :photos do
        #     collection do
        #       get 'search'
        #     end
        #   end
        #
        # This will enable Rails to recognize paths such as <tt>/photos/search</tt>
        # with GET, and route to the search action of +PhotosController+. It will also
        # create the <tt>search_photos_url</tt> and <tt>search_photos_path</tt>
        # route helpers.
        def collection
          unless resource_scope?
            raise ArgumentError, "can't use collection outside resource(s) scope"
          end

          with_scope_level(:collection) do
            scope(parent_resource.collection_scope) do
              yield
            end
          end
        end

        # To add a member route, add a member block into the resource block:
        #
        #   resources :photos do
        #     member do
        #       get 'preview'
        #     end
        #   end
        #
        # This will recognize <tt>/photos/1/preview</tt> with GET, and route to the
        # preview action of +PhotosController+. It will also create the
        # <tt>preview_photo_url</tt> and <tt>preview_photo_path</tt> helpers.
        def member
          unless resource_scope?
            raise ArgumentError, "can't use member outside resource(s) scope"
          end

          with_scope_level(:member) do
            if shallow?
              shallow_scope(parent_resource.member_scope) { yield }
            else
              scope(parent_resource.member_scope) { yield }
            end
          end
        end

        def new
          unless resource_scope?
            raise ArgumentError, "can't use new outside resource(s) scope"
          end

          with_scope_level(:new) do
            scope(parent_resource.new_scope(action_path(:new))) do
              yield
            end
          end
        end

        def nested
          unless resource_scope?
            raise ArgumentError, "can't use nested outside resource(s) scope"
          end

          with_scope_level(:nested) do
            if shallow? && shallow_nesting_depth >= 1
              shallow_scope(parent_resource.nested_scope, nested_options) { yield }
            else
              scope(parent_resource.nested_scope, nested_options) { yield }
            end
          end
        end

        # See ActionDispatch::Routing::Mapper::Scoping#namespace
        def namespace(path, options = {})
          if resource_scope?
            nested { super }
          else
            super
          end
        end

        def shallow
          scope(:shallow => true) do
            yield
          end
        end

        def shallow?
          parent_resource.instance_of?(Resource) && @scope[:shallow]
        end

        # match 'path' => 'controller#action'
        # match 'path', to: 'controller#action'
        # match 'path', 'otherpath', on: :member, via: :get
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

          if @scope[:controller] && @scope[:action]
            options[:to] ||= "#{@scope[:controller]}##{@scope[:action]}"
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
          path && (options[:to] || options[:action]).nil? && path =~ %r{^/?[-\w]+/[-\w/]+$}
        end

        def decomposed_match(path, options) # :nodoc:
          if on = options.delete(:on)
            send(on) { decomposed_match(path, options) }
          else
            case @scope.scope_level
            when :resources
              nested { decomposed_match(path, options) }
            when :resource
              member { decomposed_match(path, options) }
            else
              add_route(path, options)
            end
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

          as = if !options.fetch(:as, true) # if it's set to nil or false
                 options.delete(:as)
               else
                 name_for_action(options.delete(:as), action)
               end

          mapping = Mapping.build(@scope, @set, URI.parser.escape(path), as, options)
          app, conditions, requirements, defaults, as, anchor = mapping.to_route
          @set.add_route(app, conditions, requirements, defaults, as, anchor)
        end

        def root(path, options={})
          if path.is_a?(String)
            options[:to] = path
          elsif path.is_a?(Hash) and options.empty?
            options = path
          else
            raise ArgumentError, "must be called with a path and/or options"
          end

          if @scope.resources?
            with_scope_level(:root) do
              scope(parent_resource.path) do
                super(options)
              end
            end
          else
            super(options)
          end
        end

        protected

          def parent_resource #:nodoc:
            @scope[:scope_level_resource]
          end

          def apply_common_behavior_for(method, resources, options, &block) #:nodoc:
            if resources.length > 1
              resources.each { |r| send(method, r, options, &block) }
              return true
            end

            if options.delete(:shallow)
              shallow do
                send(method, resources.pop, options, &block)
              end
              return true
            end

            if resource_scope?
              nested { send(method, resources.pop, options, &block) }
              return true
            end

            options.keys.each do |k|
              (options[:constraints] ||= {})[k] = options.delete(k) if options[k].is_a?(Regexp)
            end

            scope_options = options.slice!(*RESOURCE_OPTIONS)
            unless scope_options.empty?
              scope(scope_options) do
                send(method, resources.pop, options, &block)
              end
              return true
            end

            unless action_options?(options)
              options.merge!(scope_action_options) if scope_action_options?
            end

            false
          end

          def action_options?(options) #:nodoc:
            options[:only] || options[:except]
          end

          def scope_action_options? #:nodoc:
            @scope[:options] && (@scope[:options][:only] || @scope[:options][:except])
          end

          def scope_action_options #:nodoc:
            @scope[:options].slice(:only, :except)
          end

          def resource_scope? #:nodoc:
            @scope.resource_scope?
          end

          def resource_method_scope? #:nodoc:
            @scope.resource_method_scope?
          end

          def nested_scope? #:nodoc:
            @scope.nested?
          end

          def with_exclusive_scope
            begin
              @scope = @scope.new(:as => nil, :path => nil)

              with_scope_level(:exclusive) do
                yield
              end
            ensure
              @scope = @scope.parent
            end
          end

          def with_scope_level(kind)
            @scope = @scope.new_level(kind)
            yield
          ensure
            @scope = @scope.parent
          end

          def resource_scope(kind, resource) #:nodoc:
            resource.shallow = @scope[:shallow]
            @scope = @scope.new(:scope_level_resource => resource)
            @nesting.push(resource)

            with_scope_level(kind) do
              scope(parent_resource.resource_scope) { yield }
            end
          ensure
            @nesting.pop
            @scope = @scope.parent
          end

          def nested_options #:nodoc:
            options = { :as => parent_resource.member_name }
            options[:constraints] = {
              parent_resource.nested_param => param_constraint
            } if param_constraint?

            options
          end

          def nesting_depth #:nodoc:
            @nesting.size
          end

          def shallow_nesting_depth #:nodoc:
            @nesting.select(&:shallow?).size
          end

          def param_constraint? #:nodoc:
            @scope[:constraints] && @scope[:constraints][parent_resource.param].is_a?(Regexp)
          end

          def param_constraint #:nodoc:
            @scope[:constraints][parent_resource.param]
          end

          def canonical_action?(action) #:nodoc:
            resource_method_scope? && CANONICAL_ACTIONS.include?(action.to_s)
          end

          def shallow_scope(path, options = {}) #:nodoc:
            scope = { :as   => @scope[:shallow_prefix],
                      :path => @scope[:shallow_path] }
            @scope = @scope.new scope

            scope(path, options) { yield }
          ensure
            @scope = @scope.parent
          end

          def path_for_action(action, path) #:nodoc:
            if path.blank? && canonical_action?(action)
              @scope[:path].to_s
            else
              "#{@scope[:path]}/#{action_path(action, path)}"
            end
          end

          def action_path(name, path = nil) #:nodoc:
            name = name.to_sym if name.is_a?(String)
            path || @scope[:path_names][name] || name.to_s
          end

          def prefix_name_for_action(as, action) #:nodoc:
            if as
              prefix = as
            elsif !canonical_action?(action)
              prefix = action
            end

            if prefix && prefix != '/' && !prefix.empty?
              Mapper.normalize_name prefix.to_s.tr('-', '_')
            end
          end

          def name_for_action(as, action) #:nodoc:
            prefix = prefix_name_for_action(as, action)
            name_prefix = @scope[:as]

            if parent_resource
              return nil unless as || action

              collection_name = parent_resource.collection_name
              member_name = parent_resource.member_name
            end

            name = @scope.action_name(name_prefix, prefix, collection_name, member_name)

            if candidate = name.compact.join("_").presence
              # If a name was not explicitly given, we check if it is valid
              # and return nil in case it isn't. Otherwise, we pass the invalid name
              # forward so the underlying router engine treats it and raises an exception.
              if as.nil?
                candidate unless candidate !~ /\A[_a-z]/i || @set.named_routes.key?(candidate)
              else
                candidate
              end
            end
          end

          def set_member_mappings_for_resource
            member do
              get :edit if parent_resource.actions.include?(:edit)
              get :show if parent_resource.actions.include?(:show)
              if parent_resource.actions.include?(:update)
                patch :update
                put   :update
              end
              delete :destroy if parent_resource.actions.include?(:destroy)
            end
          end
      end

      # Routing Concerns allow you to declare common routes that can be reused
      # inside others resources and routes.
      #
      #   concern :commentable do
      #     resources :comments
      #   end
      #
      #   concern :image_attachable do
      #     resources :images, only: :index
      #   end
      #
      # These concerns are used in Resources routing:
      #
      #   resources :messages, concerns: [:commentable, :image_attachable]
      #
      # or in a scope or namespace:
      #
      #   namespace :posts do
      #     concerns :commentable
      #   end
      module Concerns
        # Define a routing concern using a name.
        #
        # Concerns may be defined inline, using a block, or handled by
        # another object, by passing that object as the second parameter.
        #
        # The concern object, if supplied, should respond to <tt>call</tt>,
        # which will receive two parameters:
        #
        #   * The current mapper
        #   * A hash of options which the concern object may use
        #
        # Options may also be used by concerns defined in a block by accepting
        # a block parameter. So, using a block, you might do something as
        # simple as limit the actions available on certain resources, passing
        # standard resource options through the concern:
        #
        #   concern :commentable do |options|
        #     resources :comments, options
        #   end
        #
        #   resources :posts, concerns: :commentable
        #   resources :archived_posts do
        #     # Don't allow comments on archived posts
        #     concerns :commentable, only: [:index, :show]
        #   end
        #
        # Or, using a callable object, you might implement something more
        # specific to your application, which would be out of place in your
        # routes file.
        #
        #   # purchasable.rb
        #   class Purchasable
        #     def initialize(defaults = {})
        #       @defaults = defaults
        #     end
        #
        #     def call(mapper, options = {})
        #       options = @defaults.merge(options)
        #       mapper.resources :purchases
        #       mapper.resources :receipts
        #       mapper.resources :returns if options[:returnable]
        #     end
        #   end
        #
        #   # routes.rb
        #   concern :purchasable, Purchasable.new(returnable: true)
        #
        #   resources :toys, concerns: :purchasable
        #   resources :electronics, concerns: :purchasable
        #   resources :pets do
        #     concerns :purchasable, returnable: false
        #   end
        #
        # Any routing helpers can be used inside a concern. If using a
        # callable, they're accessible from the Mapper that's passed to
        # <tt>call</tt>.
        def concern(name, callable = nil, &block)
          callable ||= lambda { |mapper, options| mapper.instance_exec(options, &block) }
          @concerns[name] = callable
        end

        # Use the named concerns
        #
        #   resources :posts do
        #     concerns :commentable
        #   end
        #
        # concerns also work in any routes helper that you want to use:
        #
        #   namespace :posts do
        #     concerns :commentable
        #   end
        def concerns(*args)
          options = args.extract_options!
          args.flatten.each do |name|
            if concern = @concerns[name]
              concern.call(self, options)
            else
              raise ArgumentError, "No concern named #{name} was found!"
            end
          end
        end
      end

      class Scope # :nodoc:
        OPTIONS = [:path, :shallow_path, :as, :shallow_prefix, :module,
                   :controller, :action, :path_names, :constraints,
                   :shallow, :blocks, :defaults, :options]

        RESOURCE_SCOPES = [:resource, :resources]
        RESOURCE_METHOD_SCOPES = [:collection, :member, :new]

        attr_reader :parent, :scope_level

        def initialize(hash, parent = {}, scope_level = nil)
          @hash = hash
          @parent = parent
          @scope_level = scope_level
        end

        def nested?
          scope_level == :nested
        end

        def resources?
          scope_level == :resources
        end

        def resource_method_scope?
          RESOURCE_METHOD_SCOPES.include? scope_level
        end

        def action_name(name_prefix, prefix, collection_name, member_name)
          case scope_level
          when :nested
            [name_prefix, prefix]
          when :collection
            [prefix, name_prefix, collection_name]
          when :new
            [prefix, :new, name_prefix, member_name]
          when :member
            [prefix, name_prefix, member_name]
          when :root
            [name_prefix, collection_name, prefix]
          else
            [name_prefix, member_name, prefix]
          end
        end

        def resource_scope?
          RESOURCE_SCOPES.include? scope_level
        end

        def options
          OPTIONS
        end

        def new(hash)
          self.class.new hash, self, scope_level
        end

        def new_level(level)
          self.class.new(self, self, level)
        end

        def fetch(key, &block)
          @hash.fetch(key, &block)
        end

        def [](key)
          @hash.fetch(key) { @parent[key] }
        end

        def []=(k,v)
          @hash[k] = v
        end
      end

      def initialize(set) #:nodoc:
        @set = set
        @scope = Scope.new({ :path_names => @set.resources_path_names })
        @concerns = {}
        @nesting = []
      end

      include Base
      include HttpHelpers
      include Redirection
      include Scoping
      include Concerns
      include Resources
    end
  end
end
