module ActionDispatch
  module Routing
    class Mapper
      module Resources
        def resource(*resources, &block)
          options = resources.last.is_a?(Hash) ? resources.pop : {}

          if resources.length > 1
            raise ArgumentError if block_given?
            resources.each { |r| resource(r, options) }
            return self
          end

          resource = resources.pop

          if @scope[:scope_level] == :resources
            member do
              resource(resource, options, &block)
            end
            return self
          end

          controller(resource) do
            namespace(resource) do
              with_scope_level(:resource) do
                yield if block_given?

                get "", :to => :show
                post "", :to => :create
                put "", :to => :update
                delete "", :to => :destory
              end
            end
          end

          self
        end

        def resources(*resources, &block)
          options = resources.last.is_a?(Hash) ? resources.pop : {}

          if resources.length > 1
            raise ArgumentError if block_given?
            resources.each { |r| resources(r, options) }
            return self
          end

          resource = resources.pop

          if @scope[:scope_level] == :resources
            member do
              resources(resource, options, &block)
            end
            return self
          end

          controller(resource) do
            namespace(resource) do
              with_scope_level(:resources) do
                yield if block_given?

                member do
                  get "", :to => :show
                  put "", :to => :update
                  delete "", :to => :destory
                  get "edit", :to => :edit
                end

                collection do
                  get "", :to => :index
                  post "", :to => :create
                  get "new", :to => :new
                end
              end
            end
          end

          self
        end

        def collection
          unless @scope[:scope_level] == :resources
            raise ArgumentError, "can't use collection outside resources scope"
          end

          with_scope_level(:collection) do
            yield
          end
        end

        def member
          unless @scope[:scope_level] == :resources
            raise ArgumentError, "can't use member outside resources scope"
          end

          with_scope_level(:member) do
            scope(":id") do
              yield
            end
          end
        end

        def match(*args)
          options = args.last.is_a?(Hash) ? args.pop : {}
          args.push(options)

          case options.delete(:on)
          when :collection
            return collection { match(*args) }
          when :member
            return member { match(*args) }
          end

          if @scope[:scope_level] == :resources
            raise ArgumentError, "can't define route directly in resources scope"
          end

          super
        end

        private
          def with_scope_level(kind)
            old, @scope[:scope_level] = @scope[:scope_level], kind
            yield
          ensure
            @scope[:scope_level] = old
          end
      end

      module Scoping
        def scope(*args)
          options = args.last.is_a?(Hash) ? args.pop : {}

          constraints = options.delete(:constraints) || {}
          unless constraints.is_a?(Hash)
            block, constraints = constraints, {}
          end
          constraints, @scope[:constraints] = @scope[:constraints], (@scope[:constraints] || {}).merge(constraints)
          blocks, @scope[:blocks] = @scope[:blocks], (@scope[:blocks] || []) + [block]

          options, @scope[:options] = @scope[:options], (@scope[:options] || {}).merge(options)

          path_set = controller_set = false

          case args.first
          when String
            path_set = true
            path = args.first
            path, @scope[:path] = @scope[:path], "#{@scope[:path]}#{Rack::Mount::Utils.normalize_path(path)}"
          when Symbol
            controller_set = true
            controller = args.first
            controller, @scope[:controller] = @scope[:controller], controller
          end

          yield

          self
        ensure
          @scope[:path] = path if path_set
          @scope[:controller] = controller if controller_set
          @scope[:options] = options
          @scope[:blocks] = blocks
          @scope[:constraints] = constraints
        end

        def controller(controller)
          scope(controller.to_sym) { yield }
        end

        def namespace(path)
          scope(path.to_s) { yield }
        end

        def constraints(constraints = {})
          scope(:constraints => constraints) { yield }
        end
      end

      class Constraints
        def initialize(app, constraints = [])
          @app, @constraints = app, constraints
        end

        def call(env)
          req = Rack::Request.new(env)

          @constraints.each { |constraint|
            if constraint.respond_to?(:matches?) && !constraint.matches?(req)
              return Rack::Mount::Const::EXPECTATION_FAILED_RESPONSE
            elsif constraint.respond_to?(:call) && !constraint.call(req)
              return Rack::Mount::Const::EXPECTATION_FAILED_RESPONSE
            end
          }

          @app.call(env)
        end
      end

      def initialize(set)
        @set = set
        @scope = {}

        extend Scoping
        extend Resources
      end

      def get(*args, &block)
        map_method(:get, *args, &block)
      end

      def post(*args, &block)
        map_method(:post, *args, &block)
      end

      def put(*args, &block)
        map_method(:put, *args, &block)
      end

      def delete(*args, &block)
        map_method(:delete, *args, &block)
      end

      def match(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}

        if args.length > 1
          args.each { |path| match(path, options) }
          return self
        end

        if args.first.is_a?(Symbol)
          return match(args.first.to_s, options.merge(:to => args.first.to_sym))
        end

        path = args.first

        options = (@scope[:options] || {}).merge(options)
        conditions, defaults = {}, {}

        path = nil if path == ""
        path = Rack::Mount::Utils.normalize_path(path) if path
        path = "#{@scope[:path]}#{path}" if @scope[:path]

        raise ArgumentError, "path is required" unless path

        constraints = options[:constraints] || {}
        unless constraints.is_a?(Hash)
          block, constraints = constraints, {}
        end
        blocks = ((@scope[:blocks] || []) + [block]).compact
        constraints = (@scope[:constraints] || {}).merge(constraints)
        options.each { |k, v| constraints[k] = v if v.is_a?(Regexp) }

        conditions[:path_info] = path
        requirements = constraints.dup

        path_regexp = Rack::Mount::Strexp.compile(path, constraints, SEPARATORS)
        segment_keys = Rack::Mount::RegexpWithNamedGroups.new(path_regexp).names
        constraints.reject! { |k, v| segment_keys.include?(k.to_s) }
        conditions.merge!(constraints)

        if via = options[:via]
          via = Array(via).map { |m| m.to_s.upcase }
          conditions[:request_method] = Regexp.union(*via)
        end

        defaults[:controller] = @scope[:controller].to_s if @scope[:controller]

        if options[:to].respond_to?(:call)
          app = options[:to]
          defaults.delete(:controller)
          defaults.delete(:action)
        elsif options[:to].is_a?(String)
          defaults[:controller], defaults[:action] = options[:to].split('#')
        elsif options[:to].is_a?(Symbol)
          defaults[:action] = options[:to].to_s
        end
        app ||= Routing::RouteSet::Dispatcher.new(:defaults => defaults)

        if app.is_a?(Routing::RouteSet::Dispatcher)
          unless defaults.include?(:controller) || segment_keys.include?("controller")
            raise ArgumentError, "missing :controller"
          end
          unless defaults.include?(:action) || segment_keys.include?("action")
            raise ArgumentError, "missing :action"
          end
        end

        app = Constraints.new(app, blocks) if blocks.any?
        @set.add_route(app, conditions, requirements, defaults, options[:as])

        self
      end

      def redirect(path, options = {})
        status = options[:status] || 301
        lambda { |env|
          req = Rack::Request.new(env)
          url = req.scheme + '://' + req.host + path
          [status, {'Location' => url, 'Content-Type' => 'text/html'}, ['Moved Permanently']]
        }
      end

      private
        def map_method(method, *args, &block)
          options = args.last.is_a?(Hash) ? args.pop : {}
          options[:via] = method
          args.push(options)
          match(*args, &block)
          self
        end
    end
  end
end
