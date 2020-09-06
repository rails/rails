# frozen_string_literal: true

require 'action_dispatch/journey'
require 'active_support/core_ext/object/to_query'
require 'active_support/core_ext/module/redefine_method'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/array/extract_options'
require 'action_controller/metal/exceptions'
require 'action_dispatch/http/request'
require 'action_dispatch/routing/endpoint'

module ActionDispatch
  module Routing
    # :stopdoc:
    class RouteSet
      # Since the router holds references to many parts of the system
      # like engines, controllers and the application itself, inspecting
      # the route set can actually be really slow, therefore we default
      # alias inspect to to_s.
      alias inspect to_s

      class Dispatcher < Routing::Endpoint
        def initialize(raise_on_name_error)
          @raise_on_name_error = raise_on_name_error
        end

        def dispatcher?; true; end

        def serve(req)
          params     = req.path_parameters
          controller = controller req
          res        = controller.make_response! req
          dispatch(controller, params[:action], req, res)
        rescue ActionController::RoutingError
          if @raise_on_name_error
            raise
          else
            [404, { 'X-Cascade' => 'pass' }, []]
          end
        end

      private
        def controller(req)
          req.controller_class
        rescue NameError => e
          raise ActionController::RoutingError, e.message, e.backtrace
        end

        def dispatch(controller, action, req, res)
          controller.dispatch(action, req, res)
        end
      end

      class StaticDispatcher < Dispatcher
        def initialize(controller_class)
          super(false)
          @controller_class = controller_class
        end

        private
          def controller(_); @controller_class; end
      end

      # A NamedRouteCollection instance is a collection of named routes, and also
      # maintains an anonymous module that can be used to install helpers for the
      # named routes.
      class NamedRouteCollection
        include Enumerable
        attr_reader :routes, :url_helpers_module, :path_helpers_module
        private :routes

        def initialize
          @routes = {}
          @path_helpers = Set.new
          @url_helpers = Set.new
          @url_helpers_module  = Module.new
          @path_helpers_module = Module.new
        end

        def route_defined?(name)
          key = name.to_sym
          @path_helpers.include?(key) || @url_helpers.include?(key)
        end

        def helper_names
          @path_helpers.map(&:to_s) + @url_helpers.map(&:to_s)
        end

        def clear!
          @path_helpers.each do |helper|
            @path_helpers_module.remove_method helper
          end

          @url_helpers.each do |helper|
            @url_helpers_module.remove_method helper
          end

          @routes.clear
          @path_helpers.clear
          @url_helpers.clear
        end

        def add(name, route)
          key       = name.to_sym
          path_name = :"#{name}_path"
          url_name  = :"#{name}_url"

          if routes.key? key
            @path_helpers_module.undef_method path_name
            @url_helpers_module.undef_method url_name
          end
          routes[key] = route

          helper = UrlHelper.create(route, route.defaults, name)
          define_url_helper @path_helpers_module, path_name, helper, PATH
          define_url_helper @url_helpers_module, url_name, helper, UNKNOWN

          @path_helpers << path_name
          @url_helpers << url_name
        end

        def get(name)
          routes[name.to_sym]
        end

        def key?(name)
          return unless name
          routes.key? name.to_sym
        end

        alias []=   add
        alias []    get
        alias clear clear!

        def each
          routes.each { |name, route| yield name, route }
          self
        end

        def names
          routes.keys
        end

        def length
          routes.length
        end

        # Given a +name+, defines name_path and name_url helpers.
        # Used by 'direct', 'resolve', and 'polymorphic' route helpers.
        def add_url_helper(name, defaults, &block)
          helper = CustomUrlHelper.new(name, defaults, &block)
          path_name = :"#{name}_path"
          url_name = :"#{name}_url"

          @path_helpers_module.module_eval do
            redefine_method(path_name) do |*args|
              helper.call(self, args, true)
            end
          end

          @url_helpers_module.module_eval do
            redefine_method(url_name) do |*args|
              helper.call(self, args, false)
            end
          end

          @path_helpers << path_name
          @url_helpers << url_name

          self
        end

        class UrlHelper
          def self.create(route, options, route_name)
            if optimize_helper?(route)
              OptimizedUrlHelper.new(route, options, route_name)
            else
              new(route, options, route_name)
            end
          end

          def self.optimize_helper?(route)
            route.path.requirements.empty? && !route.glob?
          end

          attr_reader :route_name

          class OptimizedUrlHelper < UrlHelper
            attr_reader :arg_size

            def initialize(route, options, route_name)
              super
              @required_parts = @route.required_parts
              @arg_size       = @required_parts.size
            end

            def call(t, method_name, args, inner_options, url_strategy)
              if args.size == arg_size && !inner_options && optimize_routes_generation?(t)
                options = t.url_options.merge @options
                options[:path] = optimized_helper(args)

                original_script_name = options.delete(:original_script_name)
                script_name = t._routes.find_script_name(options)

                if original_script_name
                  script_name = original_script_name + script_name
                end

                options[:script_name] = script_name

                url_strategy.call options
              else
                super
              end
            end

            private
              def optimized_helper(args)
                params = parameterize_args(args) do
                  raise_generation_error(args)
                end

                @route.format params
              end

              def optimize_routes_generation?(t)
                t.send(:optimize_routes_generation?)
              end

              def parameterize_args(args)
                params = {}
                @arg_size.times { |i|
                  key = @required_parts[i]
                  value = args[i].to_param
                  yield key if value.nil? || value.empty?
                  params[key] = value
                }
                params
              end

              def raise_generation_error(args)
                missing_keys = []
                params = parameterize_args(args) { |missing_key|
                  missing_keys << missing_key
                }
                constraints = Hash[@route.requirements.merge(params).sort_by { |k, v| k.to_s }]
                message = +"No route matches #{constraints.inspect}"
                message << ", missing required keys: #{missing_keys.sort.inspect}"

                raise ActionController::UrlGenerationError, message
              end
          end

          def initialize(route, options, route_name)
            @options      = options
            @segment_keys = route.segment_keys.uniq
            @route        = route
            @route_name   = route_name
          end

          def call(t, method_name, args, inner_options, url_strategy)
            controller_options = t.url_options
            options = controller_options.merge @options
            hash = handle_positional_args(controller_options,
                                          inner_options || {},
                                          args,
                                          options,
                                          @segment_keys)

            t._routes.url_for(hash, route_name, url_strategy, method_name)
          end

          def handle_positional_args(controller_options, inner_options, args, result, path_params)
            if args.size > 0
              # take format into account
              if path_params.include?(:format)
                path_params_size = path_params.size - 1
              else
                path_params_size = path_params.size
              end

              if args.size < path_params_size
                path_params -= controller_options.keys
                path_params -= result.keys
              else
                path_params = path_params.dup
              end
              inner_options.each_key do |key|
                path_params.delete(key)
              end

              args.each_with_index do |arg, index|
                param = path_params[index]
                result[param] = arg if param
              end
            end

            result.merge!(inner_options)
          end
        end

        private
          # Create a URL helper allowing ordered parameters to be associated
          # with corresponding dynamic segments, so you can do:
          #
          #   foo_url(bar, baz, bang)
          #
          # Instead of:
          #
          #   foo_url(bar: bar, baz: baz, bang: bang)
          #
          # Also allow options hash, so you can do:
          #
          #   foo_url(bar, baz, bang, sort_by: 'baz')
          #
          def define_url_helper(mod, name, helper, url_strategy)
            mod.define_method(name) do |*args|
              last = args.last
              options = \
                case last
                when Hash
                  args.pop
                when ActionController::Parameters
                  args.pop.to_h
                end
              helper.call(self, name, args, options, url_strategy)
            end
          end
      end

      # strategy for building URLs to send to the client
      PATH    = ->(options) { ActionDispatch::Http::URL.path_for(options) }
      UNKNOWN = ->(options) { ActionDispatch::Http::URL.url_for(options) }

      attr_accessor :formatter, :set, :named_routes, :default_scope, :router
      attr_accessor :disable_clear_and_finalize, :resources_path_names
      attr_accessor :default_url_options, :draw_paths
      attr_reader :env_key, :polymorphic_mappings

      alias :routes :set

      def self.default_resources_path_names
        { new: 'new', edit: 'edit' }
      end

      def self.new_with_config(config)
        route_set_config = DEFAULT_CONFIG

        # engines apparently don't have this set
        if config.respond_to? :relative_url_root
          route_set_config.relative_url_root = config.relative_url_root
        end

        if config.respond_to? :api_only
          route_set_config.api_only = config.api_only
        end

        new route_set_config
      end

      Config = Struct.new :relative_url_root, :api_only

      DEFAULT_CONFIG = Config.new(nil, false)

      def initialize(config = DEFAULT_CONFIG)
        self.named_routes = NamedRouteCollection.new
        self.resources_path_names = self.class.default_resources_path_names
        self.default_url_options = {}
        self.draw_paths = []

        @config                     = config
        @append                     = []
        @prepend                    = []
        @disable_clear_and_finalize = false
        @finalized                  = false
        @env_key                    = "ROUTES_#{object_id}_SCRIPT_NAME"

        @set    = Journey::Routes.new
        @router = Journey::Router.new @set
        @formatter = Journey::Formatter.new self
        @polymorphic_mappings = {}
      end

      def eager_load!
        router.eager_load!
        routes.each(&:eager_load!)
        nil
      end

      def relative_url_root
        @config.relative_url_root
      end

      def api_only?
        @config.api_only
      end

      def request_class
        ActionDispatch::Request
      end

      def make_request(env)
        request_class.new env
      end
      private :make_request

      def draw(&block)
        clear! unless @disable_clear_and_finalize
        eval_block(block)
        finalize! unless @disable_clear_and_finalize
        nil
      end

      def append(&block)
        @append << block
      end

      def prepend(&block)
        @prepend << block
      end

      def eval_block(block)
        mapper = Mapper.new(self)
        if default_scope
          mapper.with_default_scope(default_scope, &block)
        else
          mapper.instance_exec(&block)
        end
      end
      private :eval_block

      def finalize!
        return if @finalized
        @append.each { |blk| eval_block(blk) }
        @finalized = true
      end

      def clear!
        @finalized = false
        named_routes.clear
        set.clear
        formatter.clear
        @polymorphic_mappings.clear
        @prepend.each { |blk| eval_block(blk) }
      end

      module MountedHelpers
        extend ActiveSupport::Concern
        include UrlFor
      end

      # Contains all the mounted helpers across different
      # engines and the `main_app` helper for the application.
      # You can include this in your classes if you want to
      # access routes for other engines.
      def mounted_helpers
        MountedHelpers
      end

      def define_mounted_helper(name, script_namer = nil)
        return if MountedHelpers.method_defined?(name)

        routes = self
        helpers = routes.url_helpers

        MountedHelpers.class_eval do
          define_method "_#{name}" do
            RoutesProxy.new(routes, _routes_context, helpers, script_namer)
          end
        end

        MountedHelpers.class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
          def #{name}
            @_#{name} ||= _#{name}
          end
        RUBY
      end

      def url_helpers(supports_path = true)
        if supports_path
          @url_helpers_with_paths ||= generate_url_helpers(true)
        else
          @url_helpers_without_paths ||= generate_url_helpers(false)
        end
      end

      def generate_url_helpers(supports_path)
        routes = self

        Module.new do
          extend ActiveSupport::Concern
          include UrlFor

          # Define url_for in the singleton level so one can do:
          # Rails.application.routes.url_helpers.url_for(args)
          proxy_class = Class.new do
            include UrlFor
            include routes.named_routes.path_helpers_module
            include routes.named_routes.url_helpers_module

            attr_reader :_routes

            def initialize(routes)
              @_routes = routes
            end

            def optimize_routes_generation?
              @_routes.optimize_routes_generation?
            end
          end

          @_proxy = proxy_class.new(routes)

          class << self
            def url_for(options)
              @_proxy.url_for(options)
            end

            def full_url_for(options)
              @_proxy.full_url_for(options)
            end

            def route_for(name, *args)
              @_proxy.route_for(name, *args)
            end

            def optimize_routes_generation?
              @_proxy.optimize_routes_generation?
            end

            def polymorphic_url(record_or_hash_or_array, options = {})
              @_proxy.polymorphic_url(record_or_hash_or_array, options)
            end

            def polymorphic_path(record_or_hash_or_array, options = {})
              @_proxy.polymorphic_path(record_or_hash_or_array, options)
            end

            def _routes; @_proxy._routes; end
            def url_options; {}; end
          end

          url_helpers = routes.named_routes.url_helpers_module

          # Make named_routes available in the module singleton
          # as well, so one can do:
          # Rails.application.routes.url_helpers.posts_path
          extend url_helpers

          # Any class that includes this module will get all
          # named routes...
          include url_helpers

          if supports_path
            path_helpers = routes.named_routes.path_helpers_module

            include path_helpers
            extend path_helpers
          end

          # plus a singleton class method called _routes ...
          included do
            redefine_singleton_method(:_routes) { routes }
          end

          # And an instance method _routes. Note that
          # UrlFor (included in this module) add extra
          # conveniences for working with @_routes.
          define_method(:_routes) { @_routes || routes }

          define_method(:_generate_paths_by_default) do
            supports_path
          end

          private :_generate_paths_by_default
        end
      end

      def empty?
        routes.empty?
      end

      def add_route(mapping, name)
        raise ArgumentError, "Invalid route name: '#{name}'" unless name.blank? || name.to_s.match(/^[_a-z]\w*$/i)

        if name && named_routes[name]
          raise ArgumentError, "Invalid route name, already in use: '#{name}' \n" \
            'You may have defined two routes with the same name using the `:as` option, or ' \
            'you may be overriding a route already defined by a resource with the same naming. ' \
            "For the latter, you can restrict the routes created with `resources` as explained here: \n" \
            'https://guides.rubyonrails.org/routing.html#restricting-the-routes-created'
        end

        route = @set.add_route(name, mapping)
        named_routes[name] = route if name

        if route.segment_keys.include?(:controller)
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Using a dynamic :controller segment in a route is deprecated and
            will be removed in Rails 6.1.
          MSG
        end

        if route.segment_keys.include?(:action)
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Using a dynamic :action segment in a route is deprecated and
            will be removed in Rails 6.1.
          MSG
        end

        route
      end

      def add_polymorphic_mapping(klass, options, &block)
        @polymorphic_mappings[klass] = CustomUrlHelper.new(klass, options, &block)
      end

      def add_url_helper(name, options, &block)
        named_routes.add_url_helper(name, options, &block)
      end

      class CustomUrlHelper
        attr_reader :name, :defaults, :block

        def initialize(name, defaults, &block)
          @name = name
          @defaults = defaults
          @block = block
        end

        def call(t, args, only_path = false)
          options = args.extract_options!
          url = t.full_url_for(eval_block(t, args, options))

          if only_path
            '/' + url.partition(%r{(?<!/)/(?!/)}).last
          else
            url
          end
        end

        private
          def eval_block(t, args, options)
            t.instance_exec(*args, merge_defaults(options), &block)
          end

          def merge_defaults(options)
            defaults ? defaults.merge(options) : options
          end
      end

      class Generator
        attr_reader :options, :recall, :set, :named_route

        def initialize(named_route, options, recall, set)
          @named_route = named_route
          @options     = options
          @recall      = recall
          @set         = set

          normalize_options!
          normalize_controller_action_id!
          use_relative_controller!
          normalize_controller!
        end

        def controller
          @options[:controller]
        end

        def current_controller
          @recall[:controller]
        end

        def use_recall_for(key)
          if @recall[key] && (!@options.key?(key) || @options[key] == @recall[key])
            if !named_route_exists? || segment_keys.include?(key)
              @options[key] = @recall[key]
            end
          end
        end

        def normalize_options!
          # If an explicit :controller was given, always make :action explicit
          # too, so that action expiry works as expected for things like
          #
          #   generate({controller: 'content'}, {controller: 'content', action: 'show'})
          #
          # (the above is from the unit tests). In the above case, because the
          # controller was explicitly given, but no action, the action is implied to
          # be "index", not the recalled action of "show".

          if options[:controller]
            options[:action]     ||= 'index'
            options[:controller]   = options[:controller].to_s
          end

          if options.key?(:action)
            options[:action] = (options[:action] || 'index').to_s
          end
        end

        # This pulls :controller, :action, and :id out of the recall.
        # The recall key is only used if there is no key in the options
        # or if the key in the options is identical. If any of
        # :controller, :action or :id is not found, don't pull any
        # more keys from the recall.
        def normalize_controller_action_id!
          use_recall_for(:controller) || return
          use_recall_for(:action) || return
          use_recall_for(:id)
        end

        # if the current controller is "foo/bar/baz" and controller: "baz/bat"
        # is specified, the controller becomes "foo/baz/bat"
        def use_relative_controller!
          if !named_route && different_controller? && !controller.start_with?('/')
            old_parts = current_controller.split('/')
            size = controller.count('/') + 1
            parts = old_parts[0...-size] << controller
            @options[:controller] = parts.join('/')
          end
        end

        # Remove leading slashes from controllers
        def normalize_controller!
          if controller
            if controller.start_with?('/')
              @options[:controller] = controller[1..-1]
            else
              @options[:controller] = controller
            end
          end
        end

        # Generates a path from routes, returns a RouteWithParams or MissingRoute.
        # MissingRoute will raise ActionController::UrlGenerationError.
        def generate
          @set.formatter.generate(named_route, options, recall)
        end

        def different_controller?
          return false unless current_controller
          controller.to_param != current_controller.to_param
        end

        private
          def named_route_exists?
            named_route && set.named_routes[named_route]
          end

          def segment_keys
            set.named_routes[named_route].segment_keys
          end
      end

      # Generate the path indicated by the arguments, and return an array of
      # the keys that were not used to generate it.
      def extra_keys(options, recall = {})
        generate_extras(options, recall).last
      end

      def generate_extras(options, recall = {})
        if recall
          options = options.merge(_recall: recall)
        end

        route_name = options.delete :use_route
        path = path_for(options, route_name, [])

        uri = URI.parse(path)
        params = Rack::Utils.parse_nested_query(uri.query).symbolize_keys
        [uri.path, params.keys]
      end

      def generate(route_name, options, recall = {}, method_name = nil)
        Generator.new(route_name, options, recall, self).generate
      end
      private :generate

      RESERVED_OPTIONS = [:host, :protocol, :port, :subdomain, :domain, :tld_length,
                          :trailing_slash, :anchor, :params, :only_path, :script_name,
                          :original_script_name, :relative_url_root]

      def optimize_routes_generation?
        default_url_options.empty?
      end

      def find_script_name(options)
        options.delete(:script_name) || find_relative_url_root(options) || ''
      end

      def find_relative_url_root(options)
        options.delete(:relative_url_root) || relative_url_root
      end

      def path_for(options, route_name = nil, reserved = RESERVED_OPTIONS)
        url_for(options, route_name, PATH, nil, reserved)
      end

      # The +options+ argument must be a hash whose keys are *symbols*.
      def url_for(options, route_name = nil, url_strategy = UNKNOWN, method_name = nil, reserved = RESERVED_OPTIONS)
        options = default_url_options.merge options

        user = password = nil

        if options[:user] && options[:password]
          user     = options.delete :user
          password = options.delete :password
        end

        recall = options.delete(:_recall) { {} }

        original_script_name = options.delete(:original_script_name)
        script_name = find_script_name options

        if original_script_name
          script_name = original_script_name + script_name
        end

        path_options = options.dup
        reserved.each { |ro| path_options.delete ro }

        route_with_params = generate(route_name, path_options, recall)
        path = route_with_params.path(method_name)
        params = route_with_params.params

        if options.key? :params
          params.merge! options[:params]
        end

        options[:path]        = path
        options[:script_name] = script_name
        options[:params]      = params
        options[:user]        = user
        options[:password]    = password

        url_strategy.call options
      end

      def call(env)
        req = make_request(env)
        req.path_info = Journey::Router::Utils.normalize_path(req.path_info)
        @router.serve(req)
      end

      def recognize_path(path, environment = {})
        method = (environment[:method] || 'GET').to_s.upcase
        path = Journey::Router::Utils.normalize_path(path) unless %r{://}.match?(path)
        extras = environment[:extras] || {}

        begin
          env = Rack::MockRequest.env_for(path, method: method)
        rescue URI::InvalidURIError => e
          raise ActionController::RoutingError, e.message
        end

        req = make_request(env)
        recognize_path_with_request(req, path, extras)
      end

      def recognize_path_with_request(req, path, extras, raise_on_missing: true)
        @router.recognize(req) do |route, params|
          params.merge!(extras)
          params.each do |key, value|
            if value.is_a?(String)
              value = value.dup.force_encoding(Encoding::BINARY)
              params[key] = URI::DEFAULT_PARSER.unescape(value)
            end
          end
          req.path_parameters = params
          app = route.app
          if app.matches?(req) && app.dispatcher?
            begin
              req.controller_class
            rescue NameError
              raise ActionController::RoutingError, "A route matches #{path.inspect}, but references missing controller: #{params[:controller].camelize}Controller"
            end

            return req.path_parameters
          elsif app.matches?(req) && app.engine?
            path_parameters = app.rack_app.routes.recognize_path_with_request(req, path, extras, raise_on_missing: false)
            return path_parameters if path_parameters
          end
        end

        if raise_on_missing
          raise ActionController::RoutingError, "No route matches #{path.inspect}"
        end
      end
    end
    # :startdoc:
  end
end
