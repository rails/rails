module ActionDispatch
  module Routing
    class Mapper
      module Resources
        class Resource #:nodoc:
          attr_reader :plural, :singular
          attr_reader :path_prefix, :name_prefix

          def initialize(entities, options = {})
            entities = entities.to_s

            @plural   = entities.pluralize
            @singular = entities.singularize

            @path_prefix = options[:path_prefix]
            @name_prefix = options[:name_prefix]
          end

          def name
            plural
          end

          def controller
            plural
          end

          def member_name
            if name_prefix
              "#{name_prefix}_#{singular}"
            else
              singular
            end
          end

          def collection_name
            if name_prefix
              "#{name_prefix}_#{plural}"
            else
              plural
            end
          end

          def new_name
            if name_prefix
              "new_#{name_prefix}_#{singular}"
            else
              "new_#{singular}"
            end
          end

          def edit_name
            if name_prefix
              "edit_#{name_prefix}_#{singular}"
            else
              "edit_#{singular}"
            end
          end
        end

        class SingletonResource < Resource #:nodoc:
          def initialize(entity, options = {})
            super(entity)
          end

          def name
            singular
          end
        end

        def resource(*resources, &block)
          options = resources.extract_options!

          if resources.length > 1
            raise ArgumentError if block_given?
            resources.each { |r| resource(r, options) }
            return self
          end

          name_prefix = @scope[:options][:name_prefix] if @scope[:options]
          resource = SingletonResource.new(resources.pop, :name_prefix => name_prefix)

          if @scope[:scope_level] == :resources
            parent_resource = @scope[:scope_level_options][:name]
            parent_named_prefix = @scope[:scope_level_options][:name_prefix]
            with_scope_level(:member) do
              scope(":#{parent_resource}_id", :name_prefix => parent_named_prefix) do
                resource(resource.name, options, &block)
              end
            end
            return self
          end

          controller(resource.controller) do
            namespace(resource.name) do
              with_scope_level(:resource, :name => resource.singular, :name_prefix => resource.member_name) do
                yield if block_given?

                get "", :to => :show, :as => resource.member_name
                post "", :to => :create
                put "", :to => :update
                delete "", :to => :destroy
                get "new", :to => :new, :as => resource.new_name
                get "edit", :to => :edit, :as => resource.edit_name
              end
            end
          end

          self
        end

        def resources(*resources, &block)
          options = resources.extract_options!

          if resources.length > 1
            raise ArgumentError if block_given?
            resources.each { |r| resources(r, options) }
            return self
          end

          name_prefix = @scope[:options][:name_prefix] if @scope[:options]
          resource = Resource.new(resources.pop, :name_prefix => name_prefix)

          if @scope[:scope_level] == :resources
            parent_resource = @scope[:scope_level_options][:name]
            parent_named_prefix = @scope[:scope_level_options][:name_prefix]
            with_scope_level(:member) do
              scope(":#{parent_resource}_id", :name_prefix => parent_named_prefix) do
                resources(resource.name, options, &block)
              end
            end
            return self
          end

          controller(resource.controller) do
            namespace(resource.name) do
              with_scope_level(:resources, :name => resource.singular, :name_prefix => resource.member_name) do
                yield if block_given?

                collection do
                  get "", :to => :index, :as => resource.collection_name
                  post "", :to => :create
                  get "new", :to => :new, :as => resource.new_name
                end

                member do
                  get "", :to => :show, :as => resource.member_name
                  put "", :to => :update
                  delete "", :to => :destroy
                  get "edit", :to => :edit, :as => resource.edit_name
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
          options = args.extract_options!
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
          def with_scope_level(kind, options = {})
            old, @scope[:scope_level] = @scope[:scope_level], kind
            old_options, @scope[:scope_level_options] = @scope[:scope_level_options], options
            yield
          ensure
            @scope[:scope_level] = old
            @scope[:scope_level_options] = old_options
          end
      end

      module Scoping
        def self.extended(object)
          object.instance_eval do
            @scope = {}
          end
        end

        def scope(*args)
          options = args.extract_options!

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

        def match(*args)
          options = args.extract_options!
          options = (@scope[:options] || {}).merge(options)
          args.push(options)
          super(*args)
        end
      end

      module HttpHelpers
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
            options = args.extract_options!
            options[:via] = method
            args.push(options)
            match(*args, &block)
            self
          end
      end

      class Constraints
        def new(app, constraints = [])
          if constraints.any?
            super(app, constraints)
          else
            app
          end
        end

        def initialize(app, constraints = [])
          @app, @constraints = app, constraints
        end

        def call(env)
          req = Rack::Request.new(env)

          @constraints.each { |constraint|
            if constraint.respond_to?(:matches?) && !constraint.matches?(req)
              return [417, {}, []]
            elsif constraint.respond_to?(:call) && !constraint.call(req)
              return [417, {}, []]
            end
          }

          @app.call(env)
        end
      end

      def initialize(set)
        @set = set

        extend HttpHelpers
        extend Scoping
        extend Resources
      end

      def root(options = {})
        match '/', options.merge(:as => :root)
      end

      def match(*args)
        options = args.extract_options!

        if args.length > 1
          args.each { |path| match(path, options.reverse_merge(:as => path.to_sym)) }
          return self
        end

        if args.first.is_a?(Symbol)
          return match(args.first.to_s, options.merge(:to => args.first.to_sym))
        end

        path = args.first

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

        requirements[:controller] ||= @set.controller_constraints

        if via = options[:via]
          via = Array(via).map { |m| m.to_s.upcase }
          conditions[:request_method] = Regexp.union(*via)
        end

        defaults[:controller] ||= @scope[:controller].to_s if @scope[:controller]

        app = initialize_app_endpoint(options, defaults)
        validate_defaults!(app, defaults, segment_keys)
        app = Constraints.new(app, blocks)

        @set.add_route(app, conditions, requirements, defaults, options[:as])

        self
      end

      private
        def initialize_app_endpoint(options, defaults)
          app = nil

          if options[:to].respond_to?(:call)
            app = options[:to]
            defaults.delete(:controller)
            defaults.delete(:action)
          elsif options[:to].is_a?(String)
            defaults[:controller], defaults[:action] = options[:to].split('#')
          elsif options[:to].is_a?(Symbol)
            defaults[:action] = options[:to].to_s
          end

          app || Routing::RouteSet::Dispatcher.new(:defaults => defaults)
        end

        def validate_defaults!(app, defaults, segment_keys)
          return unless app.is_a?(Routing::RouteSet::Dispatcher)

          unless defaults.include?(:controller) || segment_keys.include?("controller")
            raise ArgumentError, "missing :controller"
          end

          unless defaults.include?(:action) || segment_keys.include?("action")
            raise ArgumentError, "missing :action"
          end
        end
    end
  end
end
