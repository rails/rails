require 'journey'
require 'forwardable'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/to_query'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/module/remove_method'
require 'action_controller/metal/exceptions'

module ActionDispatch
  module Routing
    class RouteSet #:nodoc:
      # Since the router holds references to many parts of the system
      # like engines, controllers and the application itself, inspecting
      # the route set can actually be really slow, therefore we default
      # alias inspect to to_s.
      alias inspect to_s

      PARAMETERS_KEY = 'action_dispatch.request.path_parameters'

      class Dispatcher #:nodoc:
        def initialize(options={})
          @defaults = options[:defaults]
          @glob_param = options.delete(:glob)
          @controllers = {}
        end

        def call(env)
          params = env[PARAMETERS_KEY]
          prepare_params!(params)

          # Just raise undefined constant errors if a controller was specified as default.
          unless controller = controller(params, @defaults.key?(:controller))
            return [404, {'X-Cascade' => 'pass'}, []]
          end

          dispatch(controller, params[:action], env)
        end

        def prepare_params!(params)
          normalize_controller!(params)
          merge_default_action!(params)
          split_glob_param!(params) if @glob_param
        end

        # If this is a default_controller (i.e. a controller specified by the user)
        # we should raise an error in case it's not found, because it usually means
        # a user error. However, if the controller was retrieved through a dynamic
        # segment, as in :controller(/:action), we should simply return nil and
        # delegate the control back to Rack cascade. Besides, if this is not a default
        # controller, it means we should respect the @scope[:module] parameter.
        def controller(params, default_controller=true)
          if params && params.key?(:controller)
            controller_param = params[:controller]
            controller_reference(controller_param)
          end
        rescue NameError => e
          raise ActionController::RoutingError, e.message, e.backtrace if default_controller
        end

      private

        def controller_reference(controller_param)
          controller_name = "#{controller_param.camelize}Controller"

          unless controller = @controllers[controller_param]
            controller = @controllers[controller_param] =
              ActiveSupport::Dependencies.reference(controller_name)
          end
          controller.get(controller_name)
        end

        def dispatch(controller, action, env)
          controller.action(action).call(env)
        end

        def normalize_controller!(params)
          params[:controller] = params[:controller].underscore if params.key?(:controller)
        end

        def merge_default_action!(params)
          params[:action] ||= 'index'
        end

        def split_glob_param!(params)
          params[@glob_param] = params[@glob_param].split('/').map { |v| URI.parser.unescape(v) }
        end
      end

      # A NamedRouteCollection instance is a collection of named routes, and also
      # maintains an anonymous module that can be used to install helpers for the
      # named routes.
      class NamedRouteCollection #:nodoc:
        include Enumerable
        attr_reader :routes, :helpers, :module

        def initialize
          clear!
        end

        def helper_names
          self.module.instance_methods.map(&:to_s)
        end

        def clear!
          @routes = {}
          @helpers = []

          @module ||= Module.new do
            instance_methods.each { |selector| remove_method(selector) }
          end
        end

        def add(name, route)
          routes[name.to_sym] = route
          define_named_route_methods(name, route)
        end

        def get(name)
          routes[name.to_sym]
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

        def reset!
          old_routes = routes.dup
          clear!
          old_routes.each do |name, route|
            add(name, route)
          end
        end

        def install(destinations = [ActionController::Base, ActionView::Base], regenerate = false)
          reset! if regenerate
          Array(destinations).each do |dest|
            dest.__send__(:include, @module)
          end
        end

        private
          def url_helper_name(name, kind = :url)
            :"#{name}_#{kind}"
          end

          def hash_access_name(name, kind = :url)
            :"hash_for_#{name}_#{kind}"
          end

          def define_named_route_methods(name, route)
            {:url => {:only_path => false}, :path => {:only_path => true}}.each do |kind, opts|
              hash = route.defaults.merge(:use_route => name).merge(opts)
              define_hash_access route, name, kind, hash
              define_url_helper route, name, kind, hash
            end
          end

          def define_hash_access(route, name, kind, options)
            selector = hash_access_name(name, kind)

            # We use module_eval to avoid leaks
            @module.module_eval <<-END_EVAL, __FILE__, __LINE__ + 1
              remove_possible_method :#{selector}
              def #{selector}(*args)
                options = args.extract_options!
                result = #{options.inspect}

                if args.any?
                  result[:_positional_args] = args
                  result[:_positional_keys] = #{route.segment_keys.inspect}
                end

                result.merge(options)
              end
              protected :#{selector}
            END_EVAL
            helpers << selector
          end

          # Create a url helper allowing ordered parameters to be associated
          # with corresponding dynamic segments, so you can do:
          #
          #   foo_url(bar, baz, bang)
          #
          # Instead of:
          #
          #   foo_url(:bar => bar, :baz => baz, :bang => bang)
          #
          # Also allow options hash, so you can do:
          #
          #   foo_url(bar, baz, bang, :sort_by => 'baz')
          #
          def define_url_helper(route, name, kind, options)
            selector = url_helper_name(name, kind)
            hash_access_method = hash_access_name(name, kind)

            @module.module_eval <<-END_EVAL, __FILE__, __LINE__ + 1
              remove_possible_method :#{selector}
              def #{selector}(*args)
                url_for(#{hash_access_method}(*args))
              end
            END_EVAL
            helpers << selector
          end
      end

      attr_accessor :formatter, :set, :named_routes, :default_scope, :router
      attr_accessor :disable_clear_and_finalize, :resources_path_names
      attr_accessor :default_url_options, :request_class, :valid_conditions

      alias :routes :set

      def self.default_resources_path_names
        { :new => 'new', :edit => 'edit' }
      end

      def initialize(request_class = ActionDispatch::Request)
        self.named_routes = NamedRouteCollection.new
        self.resources_path_names = self.class.default_resources_path_names.dup
        self.default_url_options = {}

        self.request_class = request_class
        @valid_conditions = {}

        request_class.public_instance_methods.each { |m|
          @valid_conditions[m.to_sym] = true
        }
        @valid_conditions[:controller] = true
        @valid_conditions[:action] = true

        self.valid_conditions.delete(:id)

        @append                     = []
        @prepend                    = []
        @disable_clear_and_finalize = false
        @finalized                  = false

        @set    = Journey::Routes.new
        @router = Journey::Router.new(@set, {
          :parameters_key => PARAMETERS_KEY,
          :request_class  => request_class})
        @formatter = Journey::Formatter.new @set
      end

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
        if block.arity == 1
          raise "You are using the old router DSL which has been removed in Rails 3.1. " <<
            "Please check how to update your routes file at: http://www.engineyard.com/blog/2010/the-lowdown-on-routes-in-rails-3/"
        end
        mapper = Mapper.new(self)
        if default_scope
          mapper.with_default_scope(default_scope, &block)
        else
          mapper.instance_exec(&block)
        end
      end

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
        @prepend.each { |blk| eval_block(blk) }
      end

      def install_helpers(destinations = [ActionController::Base, ActionView::Base], regenerate_code = false)
        Array(destinations).each { |d| d.module_eval { include Helpers } }
        named_routes.install(destinations, regenerate_code)
      end

      module MountedHelpers
      end

      def mounted_helpers
        MountedHelpers
      end

      def define_mounted_helper(name)
        return if MountedHelpers.method_defined?(name)

        routes = self
        MountedHelpers.class_eval do
          define_method "_#{name}" do
            RoutesProxy.new(routes, self._routes_context)
          end
        end

        MountedHelpers.class_eval <<-RUBY
          def #{name}
            @#{name} ||= _#{name}
          end
        RUBY
      end

      def url_helpers
        @url_helpers ||= begin
          routes = self

          helpers = Module.new do
            extend ActiveSupport::Concern
            include UrlFor

            @_routes = routes
            class << self
              delegate :url_for, :to => '@_routes'
            end
            extend routes.named_routes.module

            # ROUTES TODO: install_helpers isn't great... can we make a module with the stuff that
            # we can include?
            # Yes plz - JP
            included do
              routes.install_helpers(self)
              singleton_class.send(:redefine_method, :_routes) { routes }
            end

            define_method(:_routes) { @_routes || routes }
          end

          helpers
        end
      end

      def empty?
        routes.empty?
      end

      def add_route(app, conditions = {}, requirements = {}, defaults = {}, name = nil, anchor = true)
        raise ArgumentError, "Invalid route name: '#{name}'" unless name.blank? || name.to_s.match(/^[_a-z]\w*$/i)

        path = build_path(conditions.delete(:path_info), requirements, SEPARATORS, anchor)
        conditions = build_conditions(conditions, valid_conditions, path.names.map { |x| x.to_sym })

        route = @set.add_route(app, path, conditions, defaults, name)
        named_routes[name] = route if name
        route
      end

      def build_path(path, requirements, separators, anchor)
        strexp = Journey::Router::Strexp.new(
            path,
            requirements,
            SEPARATORS,
            anchor)

        pattern = Journey::Path::Pattern.new(strexp)

        builder = Journey::GTG::Builder.new pattern.spec

        # Get all the symbol nodes followed by literals that are not the
        # dummy node.
        symbols = pattern.spec.grep(Journey::Nodes::Symbol).find_all { |n|
          builder.followpos(n).first.literal?
        }

        # Get all the symbol nodes preceded by literals.
        symbols.concat pattern.spec.find_all(&:literal?).map { |n|
          builder.followpos(n).first
        }.find_all(&:symbol?)

        symbols.each { |x|
          x.regexp = /(?:#{Regexp.union(x.regexp, '-')})+/
        }

        pattern
      end
      private :build_path

      def build_conditions(current_conditions, req_predicates, path_values)
        conditions = current_conditions.dup

        verbs = conditions[:request_method] || []

        # Rack-Mount requires that :request_method be a regular expression.
        # :request_method represents the HTTP verb that matches this route.
        #
        # Here we munge values before they get sent on to rack-mount.
        unless verbs.empty?
          conditions[:request_method] = %r[^#{verbs.join('|')}$]
        end
        conditions.delete_if { |k,v| !(req_predicates.include?(k) || path_values.include?(k)) }

        conditions
      end
      private :build_conditions

      class Generator #:nodoc:
        PARAMETERIZE = lambda do |name, value|
          if name == :controller
            value
          elsif value.is_a?(Array)
            value.map { |v| v.to_param }.join('/')
          elsif param = value.to_param
            param
          end
        end

        attr_reader :options, :recall, :set, :named_route

        def initialize(options, recall, set, extras = false)
          @named_route = options.delete(:use_route)
          @options     = options.dup
          @recall      = recall.dup
          @set         = set
          @extras      = extras

          normalize_options!
          normalize_controller_action_id!
          use_relative_controller!
          controller.sub!(%r{^/}, '') if controller
          handle_nil_action!
        end

        def controller
          @controller ||= @options[:controller]
        end

        def current_controller
          @recall[:controller]
        end

        def use_recall_for(key)
          if @recall[key] && (!@options.key?(key) || @options[key] == @recall[key])
            if named_route_exists?
              @options[key] = @recall.delete(key) if segment_keys.include?(key)
            else
              @options[key] = @recall.delete(key)
            end
          end
        end

        def normalize_options!
          # If an explicit :controller was given, always make :action explicit
          # too, so that action expiry works as expected for things like
          #
          #   generate({:controller => 'content'}, {:controller => 'content', :action => 'show'})
          #
          # (the above is from the unit tests). In the above case, because the
          # controller was explicitly given, but no action, the action is implied to
          # be "index", not the recalled action of "show".

          if options[:controller]
            options[:action]     ||= 'index'
            options[:controller]   = options[:controller].to_s
          end

          if options[:action]
            options[:action] = options[:action].to_s
          end
        end

        # This pulls :controller, :action, and :id out of the recall.
        # The recall key is only used if there is no key in the options
        # or if the key in the options is identical. If any of
        # :controller, :action or :id is not found, don't pull any
        # more keys from the recall.
        def normalize_controller_action_id!
          @recall[:action] ||= 'index' if current_controller

          use_recall_for(:controller) or return
          use_recall_for(:action) or return
          use_recall_for(:id)
        end

        # if the current controller is "foo/bar/baz" and :controller => "baz/bat"
        # is specified, the controller becomes "foo/baz/bat"
        def use_relative_controller!
          if !named_route && different_controller? && !controller.start_with?("/")
            old_parts = current_controller.split('/')
            size = controller.count("/") + 1
            parts = old_parts[0...-size] << controller
            @controller = @options[:controller] = parts.join("/")
          end
        end

        # This handles the case of :action => nil being explicitly passed.
        # It is identical to :action => "index"
        def handle_nil_action!
          if options.has_key?(:action) && options[:action].nil?
            options[:action] = 'index'
          end
          recall[:action] = options.delete(:action) if options[:action] == 'index'
        end

        def generate
          path, params = @set.formatter.generate(:path_info, named_route, options, recall, PARAMETERIZE)

          raise_routing_error unless path

          return [path, params.keys] if @extras

          [path, params]
        rescue Journey::Router::RoutingError
          raise_routing_error
        end

        def raise_routing_error
          raise ActionController::RoutingError, "No route matches #{options.inspect}"
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
      def extra_keys(options, recall={})
        generate_extras(options, recall).last
      end

      def generate_extras(options, recall={})
        generate(options, recall, true)
      end

      def generate(options, recall = {}, extras = false)
        Generator.new(options, recall, self, extras).generate
      end

      RESERVED_OPTIONS = [:host, :protocol, :port, :subdomain, :domain, :tld_length,
                          :trailing_slash, :anchor, :params, :only_path, :script_name]

      def _generate_prefix(options = {})
        nil
      end

      def url_for(options)
        finalize!
        options = (options || {}).reverse_merge!(default_url_options)

        handle_positional_args(options)

        user, password = extract_authentication(options)
        path_segments  = options.delete(:_path_segments)
        script_name    = options.delete(:script_name)

        path = (script_name.blank? ? _generate_prefix(options) : script_name.chomp('/')).to_s

        path_options = options.except(*RESERVED_OPTIONS)
        path_options = yield(path_options) if block_given?

        path_addition, params = generate(path_options, path_segments || {})
        path << path_addition
        params.merge!(options[:params] || {})

        ActionDispatch::Http::URL.url_for(options.merge!({
          :path => path,
          :params => params,
          :user => user,
          :password => password
        }))
      end

      def call(env)
        finalize!
        @router.call(env)
      end

      def recognize_path(path, environment = {})
        method = (environment[:method] || "GET").to_s.upcase
        path = Journey::Router::Utils.normalize_path(path) unless path =~ %r{://}

        begin
          env = Rack::MockRequest.env_for(path, {:method => method})
        rescue URI::InvalidURIError => e
          raise ActionController::RoutingError, e.message
        end

        req = @request_class.new(env)
        @router.recognize(req) do |route, matches, params|
          params.each do |key, value|
            if value.is_a?(String)
              value = value.dup.force_encoding(Encoding::BINARY) if value.encoding_aware?
              params[key] = URI.parser.unescape(value)
            end
          end

          dispatcher = route.app
          while dispatcher.is_a?(Mapper::Constraints) && dispatcher.matches?(env) do
            dispatcher = dispatcher.app
          end

          if dispatcher.is_a?(Dispatcher) && dispatcher.controller(params, false)
            dispatcher.prepare_params!(params)
            return params
          end
        end

        raise ActionController::RoutingError, "No route matches #{path.inspect}"
      end

      private

        def extract_authentication(options)
          if options[:user] && options[:password]
            [options.delete(:user), options.delete(:password)]
          else
            nil
          end
        end

        def handle_positional_args(options)
          return unless args = options.delete(:_positional_args)

          keys = options.delete(:_positional_keys)
          keys -= options.keys if args.size < keys.size - 1 # take format into account

          # Tell url_for to skip default_url_options
          options.merge!(Hash[args.zip(keys).map { |v, k| [k, v] }])
        end

    end
  end
end
