require 'rack/mount'
require 'forwardable'

module ActionDispatch
  module Routing
    class RouteSet #:nodoc:
      NotFound = lambda { |env|
        raise ActionController::RoutingError, "No route matches #{env['PATH_INFO'].inspect}"
      }

      PARAMETERS_KEY = 'action_dispatch.request.path_parameters'

      class Dispatcher
        def initialize(options = {})
          defaults = options[:defaults]
          @glob_param = options.delete(:glob)
        end

        def call(env)
          params = env[PARAMETERS_KEY]
          prepare_params!(params)

          unless controller = controller(params)
            return [404, {'X-Cascade' => 'pass'}, []]
          end

          controller.action(params[:action]).call(env)
        end

        def prepare_params!(params)
          merge_default_action!(params)
          split_glob_param!(params) if @glob_param

          params.each do |key, value|
            if value.is_a?(String)
              value = value.dup.force_encoding(Encoding::BINARY) if value.respond_to?(:force_encoding)
              params[key] = URI.unescape(value)
            end
          end
        end

        def controller(params)
          if params && params.has_key?(:controller)
            controller = "#{params[:controller].camelize}Controller"
            ActiveSupport::Inflector.constantize(controller)
          end
        rescue NameError => e
          raise unless e.message.include?(controller)
          nil
        end

        private
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
        attr_reader :routes, :helpers

        def initialize
          clear!
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

            # We use module_eval to avoid leaks.
            #
            # def users_url(*args)
            #   if args.empty? || Hash === args.first
            #     options = hash_for_users_url(args.first || {})
            #   else
            #     options = hash_for_users_url(args.extract_options!)
            #     default = default_url_options(options) if self.respond_to?(:default_url_options, true)
            #     options = (default ||= {}).merge(options)
            #
            #     keys = []
            #     keys -= options.keys if args.size < keys.size - 1
            #
            #     args = args.zip(keys).inject({}) do |h, (v, k)|
            #       h[k] = v
            #       h
            #     end
            #
            #     # Tell url_for to skip default_url_options
            #     options[:use_defaults] = false
            #     options.merge!(args)
            #   end
            #
            #   url_for(options)
            # end
            @module.module_eval <<-END_EVAL, __FILE__, __LINE__ + 1
              def #{selector}(*args)
                if args.empty? || Hash === args.first
                  options = #{hash_access_method}(args.first || {})
                else
                  options = #{hash_access_method}(args.extract_options!)
                  default = default_url_options(options) if self.respond_to?(:default_url_options, true)
                  options = (default ||= {}).merge(options)

                  keys = #{route.segment_keys.inspect}
                  keys -= options.keys if args.size < keys.size - 1 # take format into account

                  args = args.zip(keys).inject({}) do |h, (v, k)|
                    h[k] = v
                    h
                  end

                  # Tell url_for to skip default_url_options
                  options[:use_defaults] = false
                  options.merge!(args)
                end

                url_for(options)
              end
              protected :#{selector}
            END_EVAL
            helpers << selector
          end
      end

      attr_accessor :routes, :named_routes, :controller_namespaces
      attr_accessor :disable_clear_and_finalize, :resources_path_names

      def self.default_resources_path_names
        { :new => 'new', :edit => 'edit' }
      end

      def initialize
        self.routes = []
        self.named_routes = NamedRouteCollection.new
        self.resources_path_names = self.class.default_resources_path_names.dup
        self.controller_namespaces = Set.new

        @disable_clear_and_finalize = false
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
        @set.add_route(NotFound)
        install_helpers
        @set.freeze
      end

      def clear!
        # Clear the controller cache so we may discover new ones
        @controller_constraints = nil
        routes.clear
        named_routes.clear
        @set = ::Rack::Mount::RouteSet.new(:parameters_key => PARAMETERS_KEY)
      end

      def install_helpers(destinations = [ActionController::Base, ActionView::Base], regenerate_code = false)
        Array(destinations).each { |d| d.module_eval { include Helpers } }
        named_routes.install(destinations, regenerate_code)
      end

      def empty?
        routes.empty?
      end

      CONTROLLER_REGEXP = /[_a-zA-Z0-9]+/

      def controller_constraints
        @controller_constraints ||= begin
          namespaces = controller_namespaces + in_memory_controller_namespaces
          source = namespaces.map { |ns| "#{Regexp.escape(ns)}/#{CONTROLLER_REGEXP.source}" }
          source << CONTROLLER_REGEXP.source
          Regexp.compile(source.sort.reverse.join('|'))
        end
      end

      def in_memory_controller_namespaces
        namespaces = Set.new
        ActionController::Base.subclasses.each do |klass|
          controller_name = klass.underscore
          namespaces << controller_name.split('/')[0...-1].join('/')
        end
        namespaces.delete('')
        namespaces
      end

      def add_route(app, conditions = {}, requirements = {}, defaults = {}, name = nil)
        route = Route.new(app, conditions, requirements, defaults, name)
        @set.add_route(*route)
        named_routes[name] = route if name
        routes << route
        route
      end

      def options_as_params(options)
        # If an explicit :controller was given, always make :action explicit
        # too, so that action expiry works as expected for things like
        #
        #   generate({:controller => 'content'}, {:controller => 'content', :action => 'show'})
        #
        # (the above is from the unit tests). In the above case, because the
        # controller was explicitly given, but no action, the action is implied to
        # be "index", not the recalled action of "show".
        #
        # great fun, eh?

        options_as_params = options.clone
        options_as_params[:action] ||= 'index' if options[:controller]
        options_as_params[:action] = options_as_params[:action].to_s if options_as_params[:action]
        options_as_params
      end

      def build_expiry(options, recall)
        recall.inject({}) do |expiry, (key, recalled_value)|
          expiry[key] = (options.key?(key) && options[key].to_param != recalled_value.to_param)
          expiry
        end
      end

      # Generate the path indicated by the arguments, and return an array of
      # the keys that were not used to generate it.
      def extra_keys(options, recall={})
        generate_extras(options, recall).last
      end

      def generate_extras(options, recall={})
        generate(options, recall, :generate_extras)
      end

      def generate(options, recall = {}, method = :generate)
        options, recall = options.dup, recall.dup
        named_route = options.delete(:use_route)

        options = options_as_params(options)
        expire_on = build_expiry(options, recall)

        recall[:action] ||= 'index' if options[:controller] || recall[:controller]

        if recall[:controller] && (!options.has_key?(:controller) || options[:controller] == recall[:controller])
          options[:controller] = recall.delete(:controller)

          if recall[:action] && (!options.has_key?(:action) || options[:action] == recall[:action])
            options[:action] = recall.delete(:action)

            if recall[:id] && (!options.has_key?(:id) || options[:id] == recall[:id])
              options[:id] = recall.delete(:id)
            end
          end
        end

        options[:controller] = options[:controller].to_s if options[:controller]

        if !named_route && expire_on[:controller] && options[:controller] && options[:controller][0] != ?/
          old_parts = recall[:controller].split('/')
          new_parts = options[:controller].split('/')
          parts = old_parts[0..-(new_parts.length + 1)] + new_parts
          options[:controller] = parts.join('/')
        end

        options[:controller] = options[:controller][1..-1] if options[:controller] && options[:controller][0] == ?/

        merged = options.merge(recall)
        if options.has_key?(:action) && options[:action].nil?
          options.delete(:action)
          recall[:action] = 'index'
        end
        recall[:action] = options.delete(:action) if options[:action] == 'index'

        opts = {}
        opts[:parameterize] = lambda { |name, value|
          if name == :controller
            value
          elsif value.is_a?(Array)
            value.map { |v| Rack::Mount::Utils.escape_uri(v.to_param) }.join('/')
          else
            Rack::Mount::Utils.escape_uri(value.to_param)
          end
        }

        unless result = @set.generate(:path_info, named_route, options, recall, opts)
          raise ActionController::RoutingError, "No route matches #{options.inspect}"
        end

        path, params = result
        params.each do |k, v|
          if v
            params[k] = v
          else
            params.delete(k)
          end
        end

        if path && method == :generate_extras
          [path, params.keys]
        elsif path
          path << "?#{params.to_query}" if params.any?
          path
        else
          raise ActionController::RoutingError, "No route matches #{options.inspect}"
        end
      rescue Rack::Mount::RoutingError
        raise ActionController::RoutingError, "No route matches #{options.inspect}"
      end

      def call(env)
        @set.call(env)
      end

      def recognize_path(path, environment = {})
        method = (environment[:method] || "GET").to_s.upcase
        path = Rack::Mount::Utils.normalize_path(path)

        begin
          env = Rack::MockRequest.env_for(path, {:method => method})
        rescue URI::InvalidURIError => e
          raise ActionController::RoutingError, e.message
        end

        req = Rack::Request.new(env)
        @set.recognize(req) do |route, params|
          dispatcher = route.app
          if dispatcher.is_a?(Dispatcher) && dispatcher.controller(params)
            dispatcher.prepare_params!(params)
            return params
          end
        end

        raise ActionController::RoutingError, "No route matches #{path.inspect}"
      end
    end
  end
end
