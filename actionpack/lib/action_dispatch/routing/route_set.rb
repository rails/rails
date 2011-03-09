require 'rack/mount'
require 'forwardable'
require 'active_support/core_ext/object/to_query'
require 'action_dispatch/routing/deprecated_mapper'

module ActionDispatch
  module Routing
    class RouteSet #:nodoc:
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
          merge_default_action!(params)
          split_glob_param!(params) if @glob_param
        end

        # If this is a default_controller (i.e. a controller specified by the user)
        # we should raise an error in case it's not found, because it usually means
        # an user error. However, if the controller was retrieved through a dynamic
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
          unless controller = @controllers[controller_param]
            controller_name = "#{controller_param.camelize}Controller"
            controller = @controllers[controller_param] =
              ActiveSupport::Dependencies.ref(controller_name)
          end
          controller.get
        end

        def dispatch(controller, action, env)
          controller.action(action).call(env)
        end

        def merge_default_action!(params)
          params[:action] ||= 'index'
        end

        def split_glob_param!(params)
          params[@glob_param] = params[@glob_param].split('/').map { |v| URI.unescape(v) }
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
              def #{selector}(options = nil)                                      # def hash_for_users_url(options = nil)
                options ? #{options.inspect}.merge(options) : #{options.inspect}  #   options ? {:only_path=>false}.merge(options) : {:only_path=>false}
              end                                                                 # end
              protected :#{selector}                                              # protected :hash_for_users_url
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
              def #{selector}(*args)
                options =  #{hash_access_method}(args.extract_options!)

                if args.any?
                  options[:_positional_args] = args
                  options[:_positional_keys] = #{route.segment_keys.inspect}
                end

                url_for(options)
              end
            END_EVAL
            helpers << selector
          end
      end

      attr_accessor :set, :routes, :named_routes
      attr_accessor :disable_clear_and_finalize, :resources_path_names
      attr_accessor :default_url_options, :request_class, :valid_conditions

      def self.default_resources_path_names
        { :new => 'new', :edit => 'edit' }
      end

      def initialize(request_class = ActionDispatch::Request)
        self.routes = []
        self.named_routes = NamedRouteCollection.new
        self.resources_path_names = self.class.default_resources_path_names.dup
        self.controller_namespaces = Set.new
        self.default_url_options = {}

        self.request_class = request_class
        self.valid_conditions = request_class.public_instance_methods.map { |m| m.to_sym }
        self.valid_conditions.delete(:id)
        self.valid_conditions.push(:controller, :action)

        @disable_clear_and_finalize = false
        clear!
      end

      def draw(&block)
        clear! unless @disable_clear_and_finalize

        mapper = Mapper.new(self)
        if block.arity == 1
          mapper.instance_exec(DeprecatedMapper.new(self), &block)
        else
          mapper.instance_exec(&block)
        end

        finalize! unless @disable_clear_and_finalize

        nil
      end

      def finalize!
        return if @finalized
        @finalized = true
        @set.freeze
      end

      def clear!
        # Clear the controller cache so we may discover new ones
        @controller_constraints = nil
        @finalized = false
        routes.clear
        named_routes.clear
        @set = ::Rack::Mount::RouteSet.new(
          :parameters_key => PARAMETERS_KEY,
          :request_class  => request_class
        )
      end

      def install_helpers(destinations = [ActionController::Base, ActionView::Base], regenerate_code = false)
        Array(destinations).each { |d| d.module_eval { include Helpers } }
        named_routes.install(destinations, regenerate_code)
      end

      def url_helpers
        @url_helpers ||= begin
          routes = self

          helpers = Module.new do
            extend ActiveSupport::Concern
            include UrlFor

            @routes = routes
            class << self
              delegate :url_for, :to => '@routes'
            end
            extend routes.named_routes.module

            # ROUTES TODO: install_helpers isn't great... can we make a module with the stuff that
            # we can include?
            # Yes plz - JP
            included do
              routes.install_helpers(self)
              singleton_class.send(:define_method, :_routes) { routes }
            end

            define_method(:_routes) { routes }
          end

          helpers
        end
      end

      def empty?
        routes.empty?
      end

      def add_route(app, conditions = {}, requirements = {}, defaults = {}, name = nil, anchor = true)
        raise ArgumentError, "Invalid route name: '#{name}'" unless name.blank? || name.to_s.match(/^[_a-z]\w*$/i)
        route = Route.new(self, app, conditions, requirements, defaults, name, anchor)
        @set.add_route(*route)
        named_routes[name] = route if name
        routes << route
        route
      end

      class Generator #:nodoc:
        attr_reader :options, :recall, :set, :script_name, :named_route

        def initialize(options, recall, set, extras = false)
          @script_name = options.delete(:script_name)
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
          if !named_route && different_controller?
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
          path, params = @set.set.generate(:path_info, named_route, options, recall, opts)

          raise_routing_error unless path

          params.reject! {|k,v| !v.to_param}

          return [path, params.keys] if @extras

          path << "?#{params.to_query}" if params.any?
          "#{script_name}#{path}"
        rescue Rack::Mount::RoutingError
          raise_routing_error
        end

        def opts
          parameterize = lambda do |name, value|
            if name == :controller
              value
            elsif value.is_a?(Array)
              value.map { |v| Rack::Mount::Utils.escape_uri(v.to_param) }.join('/')
            else
              return nil unless param = value.to_param
              param.split('/').map { |v| Rack::Mount::Utils.escape_uri(v) }.join("/")
            end
          end
          {:parameterize => parameterize}
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

      RESERVED_OPTIONS = [:anchor, :params, :only_path, :host, :protocol, :port, :trailing_slash]

      def url_for(options)
        finalize!
        options = (options || {}).reverse_merge!(default_url_options)

        handle_positional_args(options)

        rewritten_url = ""

        path_segments = options.delete(:_path_segments)

        unless options[:only_path]
          rewritten_url << (options[:protocol] || "http")
          rewritten_url << "://" unless rewritten_url.match("://")
          rewritten_url << rewrite_authentication(options)

          raise "Missing host to link to! Please provide :host parameter or set default_url_options[:host]" unless options[:host]

          rewritten_url << options[:host]
          rewritten_url << ":#{options.delete(:port)}" if options.key?(:port)
        end

        path_options = options.except(*RESERVED_OPTIONS)
        path_options = yield(path_options) if block_given?
        path = generate(path_options, path_segments || {})

        # ROUTES TODO: This can be called directly, so script_name should probably be set in the routes
        rewritten_url << (options[:trailing_slash] ? path.sub(/\?|\z/) { "/" + $& } : path)
        rewritten_url << "##{Rack::Mount::Utils.escape_uri(options[:anchor].to_param.to_s)}" if options[:anchor]

        rewritten_url
      end

      def call(env)
        finalize!
        @set.call(env)
      end

      def recognize_path(path, environment = {})
        method = (environment[:method] || "GET").to_s.upcase
        path = Rack::Mount::Utils.normalize_path(path) unless path =~ %r{://}

        begin
          env = Rack::MockRequest.env_for(path, {:method => method})
        rescue URI::InvalidURIError => e
          raise ActionController::RoutingError, e.message
        end

        req = @request_class.new(env)
        @set.recognize(req) do |route, matches, params|
          params.each do |key, value|
            if value.is_a?(String)
              value = value.dup.force_encoding(Encoding::BINARY) if value.encoding_aware?
              params[key] = URI.unescape(value)
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
        def handle_positional_args(options)
          return unless args = options.delete(:_positional_args)

          keys = options.delete(:_positional_keys)
          keys -= options.keys if args.size < keys.size - 1 # take format into account

          args = args.zip(keys).inject({}) do |h, (v, k)|
            h[k] = v
            h
          end

          # Tell url_for to skip default_url_options
          options.merge!(args)
        end

        def rewrite_authentication(options)
          if options[:user] && options[:password]
            "#{Rack::Utils.escape(options.delete(:user))}:#{Rack::Utils.escape(options.delete(:password))}@"
          else
            ""
          end
        end
    end
  end
end
