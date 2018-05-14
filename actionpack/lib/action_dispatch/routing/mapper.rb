# frozen_string_literal: true

require "active_support/core_ext/hash/slice"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/regexp"
require "action_dispatch/routing/redirection"
require "action_dispatch/routing/endpoint"

module ActionDispatch
  module Routing
    class Mapper
      URL_OPTIONS = [:protocol, :subdomain, :domain, :host, :port]

      class Constraints < Routing::Endpoint #:nodoc:
        attr_reader :app, :constraints

        SERVE = ->(app, req) { app.serve req }
        CALL  = ->(app, req) { app.call req.env }

        def initialize(app, constraints, strategy)
          # Unwrap Constraints objects. I don't actually think it's possible
          # to pass a Constraints object to this constructor, but there were
          # multiple places that kept testing children of this object. I
          # *think* they were just being defensive, but I have no idea.
          if app.is_a?(self.class)
            constraints += app.constraints
            app = app.app
          end

          @strategy = strategy

          @app, @constraints, = app, constraints
        end

        def dispatcher?; @strategy == SERVE; end

        def matches?(req)
          @constraints.all? do |constraint|
            (constraint.respond_to?(:matches?) && constraint.matches?(req)) ||
              (constraint.respond_to?(:call) && constraint.call(*constraint_args(constraint, req)))
          end
        end

        def serve(req)
          return [ 404, { "X-Cascade" => "pass" }, [] ] unless matches?(req)

          @strategy.call @app, req
        end

        private
          def constraint_args(constraint, request)
            constraint.arity == 1 ? [request] : [request.path_parameters, request]
          end
      end

      class Mapping #:nodoc:
        ANCHOR_CHARACTERS_REGEX = %r{\A(\\A|\^)|(\\Z|\\z|\$)\Z}
        OPTIONAL_FORMAT_REGEX = %r{(?:\(\.:format\)+|\.:format|/)\Z}

        attr_reader :requirements, :defaults
        attr_reader :to, :default_controller, :default_action
        attr_reader :required_defaults, :ast

        def self.build(scope, set, ast, controller, default_action, to, via, formatted, options_constraints, anchor, options)
          options = scope[:options].merge(options) if scope[:options]

          defaults = (scope[:defaults] || {}).dup
          scope_constraints = scope[:constraints] || {}

          new set, ast, defaults, controller, default_action, scope[:module], to, formatted, scope_constraints, scope[:blocks] || [], via, options_constraints, anchor, options
        end

        def self.check_via(via)
          if via.empty?
            msg = "You should not use the `match` method in your router without specifying an HTTP method.\n" \
              "If you want to expose your action to both GET and POST, add `via: [:get, :post]` option.\n" \
              "If you want to expose your action to GET, use `get` in the router:\n" \
              "  Instead of: match \"controller#action\"\n" \
              "  Do: get \"controller#action\""
            raise ArgumentError, msg
          end
          via
        end

        def self.normalize_path(path, format)
          path = Mapper.normalize_path(path)

          if format == true
            "#{path}.:format"
          elsif optional_format?(path, format)
            "#{path}(.:format)"
          else
            path
          end
        end

        def self.optional_format?(path, format)
          format != false && path !~ OPTIONAL_FORMAT_REGEX
        end

        def initialize(set, ast, defaults, controller, default_action, modyoule, to, formatted, scope_constraints, blocks, via, options_constraints, anchor, options)
          @defaults = defaults
          @set = set

          @to                 = to
          @default_controller = controller
          @default_action     = default_action
          @ast                = ast
          @anchor             = anchor
          @via                = via
          @internal           = options.delete(:internal)

          path_params = ast.find_all(&:symbol?).map(&:to_sym)

          options = add_wildcard_options(options, formatted, ast)

          options = normalize_options!(options, path_params, modyoule)

          split_options = constraints(options, path_params)

          constraints = scope_constraints.merge Hash[split_options[:constraints] || []]

          if options_constraints.is_a?(Hash)
            @defaults = Hash[options_constraints.find_all { |key, default|
              URL_OPTIONS.include?(key) && (String === default || Integer === default)
            }].merge @defaults
            @blocks = blocks
            constraints.merge! options_constraints
          else
            @blocks = blocks(options_constraints)
          end

          requirements, conditions = split_constraints path_params, constraints
          verify_regexp_requirements requirements.map(&:last).grep(Regexp)

          formats = normalize_format(formatted)

          @requirements = formats[:requirements].merge Hash[requirements]
          @conditions = Hash[conditions]
          @defaults = formats[:defaults].merge(@defaults).merge(normalize_defaults(options))

          if path_params.include?(:action) && !@requirements.key?(:action)
            @defaults[:action] ||= "index"
          end

          @required_defaults = (split_options[:required_defaults] || []).map(&:first)
        end

        def make_route(name, precedence)
          route = Journey::Route.new(name,
                            application,
                            path,
                            conditions,
                            required_defaults,
                            defaults,
                            request_method,
                            precedence,
                            @internal)

          route
        end

        def application
          app(@blocks)
        end

        def path
          build_path @ast, requirements, @anchor
        end

        def conditions
          build_conditions @conditions, @set.request_class
        end

        def build_conditions(current_conditions, request_class)
          conditions = current_conditions.dup

          conditions.keep_if do |k, _|
            request_class.public_method_defined?(k)
          end
        end
        private :build_conditions

        def request_method
          @via.map { |x| Journey::Route.verb_matcher(x) }
        end
        private :request_method

        JOINED_SEPARATORS = SEPARATORS.join # :nodoc:

        def build_path(ast, requirements, anchor)
          pattern = Journey::Path::Pattern.new(ast, requirements, JOINED_SEPARATORS, anchor)

          # Find all the symbol nodes that are adjacent to literal nodes and alter
          # the regexp so that Journey will partition them into custom routes.
          ast.find_all { |node|
            next unless node.cat?

            if node.left.literal? && node.right.symbol?
              symbol = node.right
            elsif node.left.literal? && node.right.cat? && node.right.left.symbol?
              symbol = node.right.left
            elsif node.left.symbol? && node.right.literal?
              symbol = node.left
            elsif node.left.symbol? && node.right.cat? && node.right.left.literal?
              symbol = node.left
            else
              next
            end

            if symbol
              symbol.regexp = /(?:#{Regexp.union(symbol.regexp, '-')})+/
            end
          }

          pattern
        end
        private :build_path

        private
          def add_wildcard_options(options, formatted, path_ast)
            # Add a constraint for wildcard route to make it non-greedy and match the
            # optional format part of the route by default.
            if formatted != false
              path_ast.grep(Journey::Nodes::Star).each_with_object({}) { |node, hash|
                hash[node.name.to_sym] ||= /.+?/
              }.merge options
            else
              options
            end
          end

          def normalize_options!(options, path_params, modyoule)
            if path_params.include?(:controller)
              raise ArgumentError, ":controller segment is not allowed within a namespace block" if modyoule

              # Add a default constraint for :controller path segments that matches namespaced
              # controllers with default routes like :controller/:action/:id(.:format), e.g:
              # GET /admin/products/show/1
              # => { controller: 'admin/products', action: 'show', id: '1' }
              options[:controller] ||= /.+?/
            end

            if to.respond_to?(:action) || to.respond_to?(:call)
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
            constraints.partition do |key, requirement|
              path_params.include?(key) || key == :controller
            end
          end

          def normalize_format(formatted)
            case formatted
            when true
              { requirements: { format: /.+/ },
                defaults:     {} }
            when Regexp
              { requirements: { format: formatted },
                defaults:     { format: nil } }
            when String
              { requirements: { format: Regexp.compile(formatted) },
                defaults:     { format: formatted } }
            else
              { requirements: {}, defaults: {} }
            end
          end

          def verify_regexp_requirements(requirements)
            requirements.each do |requirement|
              if requirement.source =~ ANCHOR_CHARACTERS_REGEX
                raise ArgumentError, "Regexp anchor characters are not allowed in routing requirements: #{requirement.inspect}"
              end

              if requirement.multiline?
                raise ArgumentError, "Regexp multiline option is not allowed in routing requirements: #{requirement.inspect}"
              end
            end
          end

          def normalize_defaults(options)
            Hash[options.reject { |_, default| Regexp === default }]
          end

          def app(blocks)
            if to.respond_to?(:action)
              Routing::RouteSet::StaticDispatcher.new to
            elsif to.respond_to?(:call)
              Constraints.new(to, blocks, Constraints::CALL)
            elsif blocks.any?
              Constraints.new(dispatcher(defaults.key?(:controller)), blocks, Constraints::SERVE)
            else
              dispatcher(defaults.key?(:controller))
            end
          end

          def check_controller_and_action(path_params, controller, action)
            hash = check_part(:controller, controller, path_params, {}) do |part|
              translate_controller(part) {
                message = "'#{part}' is not a supported controller name. This can lead to potential routing problems.".dup
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
            if to =~ /#/
              to.split("#")
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

          def blocks(callable_constraint)
            unless callable_constraint.respond_to?(:call) || callable_constraint.respond_to?(:matches?)
              raise ArgumentError, "Invalid constraint: #{callable_constraint.inspect} must respond to :call or :matches?"
            end
            [callable_constraint]
          end

          def constraints(options, path_params)
            options.group_by do |key, option|
              if Regexp === option
                :constraints
              else
                if path_params.include?(key)
                  :path_params
                else
                  :required_defaults
                end
              end
            end
          end

          def dispatcher(raise_on_name_error)
            Routing::RouteSet::Dispatcher.new raise_on_name_error
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
        # Matches a URL pattern to one or more routes.
        #
        # You should not use the +match+ method in your router
        # without specifying an HTTP method.
        #
        # If you want to expose your action to both GET and POST, use:
        #
        #   # sets :controller, :action and :id in params
        #   match ':controller/:action/:id', via: [:get, :post]
        #
        # Note that +:controller+, +:action+ and +:id+ are interpreted as URL
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
        #   match 'photos/:id', to: -> (hash) { [200, {}, ["Coming soon"]] }, via: :get
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
        # Any options not seen here are passed on as params with the URL.
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
        #   In your router:
        #
        #      resources :users, param: :name
        #
        #   The +users+ resource here will have the following routes generated for it:
        #
        #      GET       /users(.:format)
        #      POST      /users(.:format)
        #      GET       /users/new(.:format)
        #      GET       /users/:name/edit(.:format)
        #      GET       /users/:name(.:format)
        #      PATCH/PUT /users/:name(.:format)
        #      DELETE    /users/:name(.:format)
        #
        #   You can override <tt>ActiveRecord::Base#to_param</tt> of a related
        #   model to construct a URL:
        #
        #      class User < ActiveRecord::Base
        #        def to_param
        #          name
        #        end
        #      end
        #
        #      user = User.find_by(name: 'Phusion')
        #      user_path(user)  # => "/users/Phusion"
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
        #      match 'path', to: -> (env) { [200, {}, ["Success!"]] }, via: :get
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
        def match(path, options = nil)
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
          elsif Hash === app
            options = app
            app, path = options.find { |k, _| k.respond_to?(:call) }
            options.delete(app) if app
          end

          raise ArgumentError, "A rack application must be specified" unless app.respond_to?(:call)
          raise ArgumentError, <<~MSG unless path
            Must be called with mount point

              mount SomeRackApp, at: "some_route"
              or
              mount(SomeRackApp => "some_route")
          MSG

          rails_app = rails_app? app
          options[:as] ||= app_name(app, rails_app)

          target_as       = name_for_action(options[:as], path)
          options[:via] ||= :all

          match(path, options.merge(to: app, anchor: false, format: false))

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
          @set.named_routes.key? name
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
            _url_helpers = @set.url_helpers

            script_namer = ->(options) do
              prefix_options = options.slice(*_route.segment_keys)
              prefix_options[:relative_url_root] = "".freeze

              if options[:_recall]
                prefix_options.reverse_merge!(options[:_recall].slice(*_route.segment_keys))
              end

              # We must actually delete prefix segment keys to avoid passing them to next url_for.
              _route.segment_keys.each { |k| options.delete(k) }
              _url_helpers.send("#{name}_path", prefix_options)
            end

            app.routes.define_mounted_helper(name, script_namer)

            app.routes.extend Module.new {
              def optimize_routes_generation?; false; end

              define_method :find_script_name do |options|
                if options.key? :script_name
                  super(options)
                else
                  script_namer.call(options)
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

          options[:path] = args.flatten.join("/") if args.any?
          options[:constraints] ||= {}

          unless nested_scope?
            options[:shallow_path] ||= options[:path] if options.key?(:path)
            options[:shallow_prefix] ||= options[:as] if options.key?(:as)
          end

          if options[:constraints].is_a?(Hash)
            defaults = options[:constraints].select do |k, v|
              URL_OPTIONS.include?(k) && (v.is_a?(String) || v.is_a?(Integer))
            end

            options[:defaults] = defaults.merge(options[:defaults] || {})
          else
            block, options[:constraints] = options[:constraints], {}
          end

          if options.key?(:only) || options.key?(:except)
            scope[:action_options] = { only: options.delete(:only),
                                       except: options.delete(:except) }
          end

          if options.key? :anchor
            raise ArgumentError, "anchor is ignored unless passed to `match`"
          end

          @scope.options.each do |option|
            if option == :blocks
              value = block
            elsif option == :options
              value = options
            else
              value = options.delete(option) { POISON }
            end

            unless POISON == value
              scope[option] = send("merge_#{option}_scope", @scope[option], value)
            end
          end

          @scope = @scope.new scope
          yield
          self
        ensure
          @scope = @scope.parent
        end

        POISON = Object.new # :nodoc:

        # Scopes routes to a specific controller
        #
        #   controller "food" do
        #     match "bacon", action: :bacon, via: :get
        #   end
        def controller(controller)
          @scope = @scope.new(controller: controller)
          yield
        ensure
          @scope = @scope.parent
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
            as:             options.fetch(:as, path),
            shallow_path:   options.fetch(:path, path),
            shallow_prefix: options.fetch(:as, path)
          }

          path_scope(options.delete(:path) { path }) do
            scope(defaults.merge!(options)) { yield }
          end
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
        #    constraints(-> (req) { req.env["HTTP_USER_AGENT"] =~ /iPhone/ }) do
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
          scope(constraints: constraints) { yield }
        end

        # Allows you to set default parameters for a route, such as this:
        #   defaults id: 'home' do
        #     match 'scoped_pages/(:id)', to: 'pages#show'
        #   end
        # Using this, the +:id+ parameter here will default to 'home'.
        def defaults(defaults = {})
          @scope = @scope.new(defaults: merge_defaults_scope(@scope[:defaults], defaults))
          yield
        ensure
          @scope = @scope.parent
        end

        private
          def merge_path_scope(parent, child)
            Mapper.normalize_path("#{parent}/#{child}")
          end

          def merge_shallow_path_scope(parent, child)
            Mapper.normalize_path("#{parent}/#{child}")
          end

          def merge_as_scope(parent, child)
            parent ? "#{parent}_#{child}" : child
          end

          def merge_shallow_prefix_scope(parent, child)
            parent ? "#{parent}_#{child}" : child
          end

          def merge_module_scope(parent, child)
            parent ? "#{parent}/#{child}" : child
          end

          def merge_controller_scope(parent, child)
            child
          end

          def merge_action_scope(parent, child)
            child
          end

          def merge_via_scope(parent, child)
            child
          end

          def merge_format_scope(parent, child)
            child
          end

          def merge_path_names_scope(parent, child)
            merge_options_scope(parent, child)
          end

          def merge_constraints_scope(parent, child)
            merge_options_scope(parent, child)
          end

          def merge_defaults_scope(parent, child)
            merge_options_scope(parent, child)
          end

          def merge_blocks_scope(parent, child)
            merged = parent ? parent.dup : []
            merged << child if child
            merged
          end

          def merge_options_scope(parent, child)
            (parent || {}).merge(child)
          end

          def merge_shallow_scope(parent, child)
            child ? true : false
          end

          def merge_to_scope(parent, child)
            child
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
          attr_reader :controller, :path, :param

          def initialize(entities, api_only, shallow, options = {})
            @name       = entities.to_s
            @path       = (options[:path] || @name).to_s
            @controller = (options[:controller] || @name).to_s
            @as         = options[:as]
            @param      = (options[:param] || :id).to_sym
            @options    = options
            @shallow    = shallow
            @api_only   = api_only
            @only       = options.delete :only
            @except     = options.delete :except
          end

          def default_actions
            if @api_only
              [:index, :create, :show, :update, :destroy]
            else
              [:index, :create, :new, :show, :update, :destroy, :edit]
            end
          end

          def actions
            if @only
              Array(@only).map(&:to_sym)
            elsif @except
              default_actions - Array(@except).map(&:to_sym)
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
            controller
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

          def shallow?
            @shallow
          end

          def singleton?; false; end
        end

        class SingletonResource < Resource #:nodoc:
          def initialize(entities, api_only, shallow, options)
            super
            @as         = nil
            @controller = (options[:controller] || plural).to_s
            @as         = options[:as]
          end

          def default_actions
            if @api_only
              [:show, :create, :update, :destroy]
            else
              [:show, :create, :update, :destroy, :new, :edit]
            end
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

          def singleton?; true; end
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
        # This creates six different routes in your application, all mapping to
        # the +Profiles+ controller (note that the controller is named after
        # the plural):
        #
        #   GET       /profile/new
        #   GET       /profile
        #   GET       /profile/edit
        #   PATCH/PUT /profile
        #   DELETE    /profile
        #   POST      /profile
        #
        # === Options
        # Takes same options as resources[rdoc-ref:#resources]
        def resource(*resources, &block)
          options = resources.extract_options!.dup

          if apply_common_behavior_for(:resource, resources, options, &block)
            return self
          end

          with_scope_level(:resource) do
            options = apply_action_options options
            resource_scope(SingletonResource.new(resources.pop, api_only?, @scope[:shallow], options)) do
              yield if block_given?

              concerns(options[:concerns]) if options[:concerns]

              new do
                get :new
              end if parent_resource.actions.include?(:new)

              set_member_mappings_for_resource

              collection do
                post :create
              end if parent_resource.actions.include?(:create)
            end
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
        # Takes same options as match[rdoc-ref:Base#match] as well as:
        #
        # [:path_names]
        #   Allows you to change the segment component of the +edit+ and +new+ actions.
        #   Actions not specified are not changed.
        #
        #     resources :posts, path_names: { new: "brand_new" }
        #
        #   The above example will now change /posts/new to /posts/brand_new.
        #
        # [:path]
        #   Allows you to change the path prefix for the resource.
        #
        #     resources :posts, path: 'postings'
        #
        #   The resource and all segments will now route to /postings instead of /posts.
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

          with_scope_level(:resources) do
            options = apply_action_options options
            resource_scope(Resource.new(resources.pop, api_only?, @scope[:shallow], options)) do
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
            path_scope(parent_resource.collection_scope) do
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
              shallow_scope {
                path_scope(parent_resource.member_scope) { yield }
              }
            else
              path_scope(parent_resource.member_scope) { yield }
            end
          end
        end

        def new
          unless resource_scope?
            raise ArgumentError, "can't use new outside resource(s) scope"
          end

          with_scope_level(:new) do
            path_scope(parent_resource.new_scope(action_path(:new))) do
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
              shallow_scope do
                path_scope(parent_resource.nested_scope) do
                  scope(nested_options) { yield }
                end
              end
            else
              path_scope(parent_resource.nested_scope) do
                scope(nested_options) { yield }
              end
            end
          end
        end

        # See ActionDispatch::Routing::Mapper::Scoping#namespace.
        def namespace(path, options = {})
          if resource_scope?
            nested { super }
          else
            super
          end
        end

        def shallow
          @scope = @scope.new(shallow: true)
          yield
        ensure
          @scope = @scope.parent
        end

        def shallow?
          !parent_resource.singleton? && @scope[:shallow]
        end

        # Matches a URL pattern to one or more routes.
        # For more information, see match[rdoc-ref:Base#match].
        #
        #   match 'path' => 'controller#action', via: :patch
        #   match 'path', to: 'controller#action', via: :post
        #   match 'path', 'otherpath', on: :member, via: :get
        def match(path, *rest, &block)
          if rest.empty? && Hash === path
            options  = path
            path, to = options.find { |name, _value| name.is_a?(String) }

            raise ArgumentError, "Route path not specified" if path.nil?

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

          if options.key?(:defaults)
            defaults(options.delete(:defaults)) { map_match(paths, options, &block) }
          else
            map_match(paths, options, &block)
          end
        end

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
        def root(path, options = {})
          if path.is_a?(String)
            options[:to] = path
          elsif path.is_a?(Hash) && options.empty?
            options = path
          else
            raise ArgumentError, "must be called with a path and/or options"
          end

          if @scope.resources?
            with_scope_level(:root) do
              path_scope(parent_resource.path) do
                match_root_route(options)
              end
            end
          else
            match_root_route(options)
          end
        end

        private

          def parent_resource
            @scope[:scope_level_resource]
          end

          def apply_common_behavior_for(method, resources, options, &block)
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

            false
          end

          def apply_action_options(options)
            return options if action_options? options
            options.merge scope_action_options
          end

          def action_options?(options)
            options[:only] || options[:except]
          end

          def scope_action_options
            @scope[:action_options] || {}
          end

          def resource_scope?
            @scope.resource_scope?
          end

          def resource_method_scope?
            @scope.resource_method_scope?
          end

          def nested_scope?
            @scope.nested?
          end

          def with_scope_level(kind) # :doc:
            @scope = @scope.new_level(kind)
            yield
          ensure
            @scope = @scope.parent
          end

          def resource_scope(resource)
            @scope = @scope.new(scope_level_resource: resource)

            controller(resource.resource_scope) { yield }
          ensure
            @scope = @scope.parent
          end

          def nested_options
            options = { as: parent_resource.member_name }
            options[:constraints] = {
              parent_resource.nested_param => param_constraint
            } if param_constraint?

            options
          end

          def shallow_nesting_depth
            @scope.find_all { |node|
              node.frame[:scope_level_resource]
            }.count { |node| node.frame[:scope_level_resource].shallow? }
          end

          def param_constraint?
            @scope[:constraints] && @scope[:constraints][parent_resource.param].is_a?(Regexp)
          end

          def param_constraint
            @scope[:constraints][parent_resource.param]
          end

          def canonical_action?(action)
            resource_method_scope? && CANONICAL_ACTIONS.include?(action.to_s)
          end

          def shallow_scope
            scope = { as: @scope[:shallow_prefix],
                      path: @scope[:shallow_path] }
            @scope = @scope.new scope

            yield
          ensure
            @scope = @scope.parent
          end

          def path_for_action(action, path)
            return "#{@scope[:path]}/#{path}" if path

            if canonical_action?(action)
              @scope[:path].to_s
            else
              "#{@scope[:path]}/#{action_path(action)}"
            end
          end

          def action_path(name)
            @scope[:path_names][name.to_sym] || name
          end

          def prefix_name_for_action(as, action)
            if as
              prefix = as
            elsif !canonical_action?(action)
              prefix = action
            end

            if prefix && prefix != "/" && !prefix.empty?
              Mapper.normalize_name prefix.to_s.tr("-", "_")
            end
          end

          def name_for_action(as, action)
            prefix = prefix_name_for_action(as, action)
            name_prefix = @scope[:as]

            if parent_resource
              return nil unless as || action

              collection_name = parent_resource.collection_name
              member_name = parent_resource.member_name
            end

            action_name = @scope.action_name(name_prefix, prefix, collection_name, member_name)
            candidate = action_name.select(&:present?).join("_")

            unless candidate.empty?
              # If a name was not explicitly given, we check if it is valid
              # and return nil in case it isn't. Otherwise, we pass the invalid name
              # forward so the underlying router engine treats it and raises an exception.
              if as.nil?
                candidate unless candidate !~ /\A[_a-z]/i || has_named_route?(candidate)
              else
                candidate
              end
            end
          end

          def set_member_mappings_for_resource # :doc:
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

          def api_only? # :doc:
            @set.api_only?
          end

          def path_scope(path)
            @scope = @scope.new(path: merge_path_scope(@scope[:path], path))
            yield
          ensure
            @scope = @scope.parent
          end

          def map_match(paths, options)
            if options[:on] && !VALID_ON_OPTIONS.include?(options[:on])
              raise ArgumentError, "Unknown scope #{on.inspect} given to :on"
            end

            if @scope[:to]
              options[:to] ||= @scope[:to]
            end

            if @scope[:controller] && @scope[:action]
              options[:to] ||= "#{@scope[:controller]}##{@scope[:action]}"
            end

            controller = options.delete(:controller) || @scope[:controller]
            option_path = options.delete :path
            to = options.delete :to
            via = Mapping.check_via Array(options.delete(:via) {
              @scope[:via]
            })
            formatted = options.delete(:format) { @scope[:format] }
            anchor = options.delete(:anchor) { true }
            options_constraints = options.delete(:constraints) || {}

            path_types = paths.group_by(&:class)
            path_types.fetch(String, []).each do |_path|
              route_options = options.dup
              if _path && option_path
                raise ArgumentError, "Ambiguous route definition. Both :path and the route path were specified as strings."
              end
              to = get_to_from_path(_path, to, route_options[:action])
              decomposed_match(_path, controller, route_options, _path, to, via, formatted, anchor, options_constraints)
            end

            path_types.fetch(Symbol, []).each do |action|
              route_options = options.dup
              decomposed_match(action, controller, route_options, option_path, to, via, formatted, anchor, options_constraints)
            end

            self
          end

          def get_to_from_path(path, to, action)
            return to if to || action

            path_without_format = path.sub(/\(\.:format\)$/, "")
            if using_match_shorthand?(path_without_format)
              path_without_format.gsub(%r{^/}, "").sub(%r{/([^/]*)$}, '#\1').tr("-", "_")
            else
              nil
            end
          end

          def using_match_shorthand?(path)
            path =~ %r{^/?[-\w]+/[-\w/]+$}
          end

          def decomposed_match(path, controller, options, _path, to, via, formatted, anchor, options_constraints)
            if on = options.delete(:on)
              send(on) { decomposed_match(path, controller, options, _path, to, via, formatted, anchor, options_constraints) }
            else
              case @scope.scope_level
              when :resources
                nested { decomposed_match(path, controller, options, _path, to, via, formatted, anchor, options_constraints) }
              when :resource
                member { decomposed_match(path, controller, options, _path, to, via, formatted, anchor, options_constraints) }
              else
                add_route(path, controller, options, _path, to, via, formatted, anchor, options_constraints)
              end
            end
          end

          def add_route(action, controller, options, _path, to, via, formatted, anchor, options_constraints)
            path = path_for_action(action, _path)
            raise ArgumentError, "path is required" if path.blank?

            action = action.to_s

            default_action = options.delete(:action) || @scope[:action]

            if action =~ /^[\w\-\/]+$/
              default_action ||= action.tr("-", "_") unless action.include?("/")
            else
              action = nil
            end

            as = if !options.fetch(:as, true) # if it's set to nil or false
              options.delete(:as)
            else
              name_for_action(options.delete(:as), action)
            end

            path = Mapping.normalize_path URI.parser.escape(path), formatted
            ast = Journey::Parser.parse path

            mapping = Mapping.build(@scope, @set, ast, controller, default_action, to, via, formatted, options_constraints, anchor, options)
            @set.add_route(mapping, as)
          end

          def match_root_route(options)
            name = has_named_route?(name_for_action(:root, nil)) ? nil : :root
            args = ["/", { as: name, via: :get }.merge!(options)]

            match(*args)
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
        # Concerns also work in any routes helper that you want to use:
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

      module CustomUrls
        # Define custom URL helpers that will be added to the application's
        # routes. This allows you to override and/or replace the default behavior
        # of routing helpers, e.g:
        #
        #   direct :homepage do
        #     "http://www.rubyonrails.org"
        #   end
        #
        #   direct :commentable do |model|
        #     [ model, anchor: model.dom_id ]
        #   end
        #
        #   direct :main do
        #     { controller: "pages", action: "index", subdomain: "www" }
        #   end
        #
        # The return value from the block passed to +direct+ must be a valid set of
        # arguments for +url_for+ which will actually build the URL string. This can
        # be one of the following:
        #
        # * A string, which is treated as a generated URL
        # * A hash, e.g. <tt>{ controller: "pages", action: "index" }</tt>
        # * An array, which is passed to +polymorphic_url+
        # * An Active Model instance
        # * An Active Model class
        #
        # NOTE: Other URL helpers can be called in the block but be careful not to invoke
        # your custom URL helper again otherwise it will result in a stack overflow error.
        #
        # You can also specify default options that will be passed through to
        # your URL helper definition, e.g:
        #
        #   direct :browse, page: 1, size: 10 do |options|
        #     [ :products, options.merge(params.permit(:page, :size).to_h.symbolize_keys) ]
        #   end
        #
        # In this instance the +params+ object comes from the context in which the
        # block is executed, e.g. generating a URL inside a controller action or a view.
        # If the block is executed where there isn't a +params+ object such as this:
        #
        #   Rails.application.routes.url_helpers.browse_path
        #
        # then it will raise a +NameError+. Because of this you need to be aware of the
        # context in which you will use your custom URL helper when defining it.
        #
        # NOTE: The +direct+ method can't be used inside of a scope block such as
        # +namespace+ or +scope+ and will raise an error if it detects that it is.
        def direct(name, options = {}, &block)
          unless @scope.root?
            raise RuntimeError, "The direct method can't be used inside a routes scope block"
          end

          @set.add_url_helper(name, options, &block)
        end

        # Define custom polymorphic mappings of models to URLs. This alters the
        # behavior of +polymorphic_url+ and consequently the behavior of
        # +link_to+ and +form_for+ when passed a model instance, e.g:
        #
        #   resource :basket
        #
        #   resolve "Basket" do
        #     [:basket]
        #   end
        #
        # This will now generate "/basket" when a +Basket+ instance is passed to
        # +link_to+ or +form_for+ instead of the standard "/baskets/:id".
        #
        # NOTE: This custom behavior only applies to simple polymorphic URLs where
        # a single model instance is passed and not more complicated forms, e.g:
        #
        #   # config/routes.rb
        #   resource :profile
        #   namespace :admin do
        #     resources :users
        #   end
        #
        #   resolve("User") { [:profile] }
        #
        #   # app/views/application/_menu.html.erb
        #   link_to "Profile", @current_user
        #   link_to "Profile", [:admin, @current_user]
        #
        # The first +link_to+ will generate "/profile" but the second will generate
        # the standard polymorphic URL of "/admin/users/1".
        #
        # You can pass options to a polymorphic mapping - the arity for the block
        # needs to be two as the instance is passed as the first argument, e.g:
        #
        #   resolve "Basket", anchor: "items" do |basket, options|
        #     [:basket, options]
        #   end
        #
        # This generates the URL "/basket#items" because when the last item in an
        # array passed to +polymorphic_url+ is a hash then it's treated as options
        # to the URL helper that gets called.
        #
        # NOTE: The +resolve+ method can't be used inside of a scope block such as
        # +namespace+ or +scope+ and will raise an error if it detects that it is.
        def resolve(*args, &block)
          unless @scope.root?
            raise RuntimeError, "The resolve method can't be used inside a routes scope block"
          end

          options = args.extract_options!
          args = args.flatten(1)

          args.each do |klass|
            @set.add_polymorphic_mapping(klass, options, &block)
          end
        end
      end

      class Scope # :nodoc:
        OPTIONS = [:path, :shallow_path, :as, :shallow_prefix, :module,
                   :controller, :action, :path_names, :constraints,
                   :shallow, :blocks, :defaults, :via, :format, :options, :to]

        RESOURCE_SCOPES = [:resource, :resources]
        RESOURCE_METHOD_SCOPES = [:collection, :member, :new]

        attr_reader :parent, :scope_level

        def initialize(hash, parent = NULL, scope_level = nil)
          @hash = hash
          @parent = parent
          @scope_level = scope_level
        end

        def nested?
          scope_level == :nested
        end

        def null?
          @hash.nil? && @parent.nil?
        end

        def root?
          @parent.null?
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
          self.class.new(frame, self, level)
        end

        def [](key)
          scope = find { |node| node.frame.key? key }
          scope && scope.frame[key]
        end

        include Enumerable

        def each
          node = self
          until node.equal? NULL
            yield node
            node = node.parent
          end
        end

        def frame; @hash; end

        NULL = Scope.new(nil, nil)
      end

      def initialize(set) #:nodoc:
        @set = set
        @scope = Scope.new(path_names: @set.resources_path_names)
        @concerns = {}
      end

      include Base
      include HttpHelpers
      include Redirection
      include Scoping
      include Concerns
      include Resources
      include CustomUrls
    end
  end
end
