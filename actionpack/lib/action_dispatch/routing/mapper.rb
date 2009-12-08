module ActionDispatch
  module Routing
    class Mapper
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

      module Base
        def initialize(set)
          @set = set
        end

        def root(options = {})
          match '/', options.merge(:as => :root)
        end

        def match(*args)
          options = args.extract_options!

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

      module Scoping
        def initialize(*args)
          @scope = {}
          super
        end

        def scope(*args)
          options = args.extract_options!

          case args.first
          when String
            options[:path] = args.first
          when Symbol
            options[:controller] = args.first
          end

          if path = options.delete(:path)
            path_set = true
            path, @scope[:path] = @scope[:path], "#{@scope[:path]}#{Rack::Mount::Utils.normalize_path(path)}"
          else
            path_set = false
          end

          if name_prefix = options.delete(:name_prefix)
            name_prefix_set = true
            name_prefix, @scope[:name_prefix] = @scope[:name_prefix], (@scope[:name_prefix] ? "#{@scope[:name_prefix]}_#{name_prefix}" : name_prefix)
          else
            name_prefix_set = false
          end

          if controller = options.delete(:controller)
            controller_set = true
            controller, @scope[:controller] = @scope[:controller], controller
          else
            controller_set = false
          end

          constraints = options.delete(:constraints) || {}
          unless constraints.is_a?(Hash)
            block, constraints = constraints, {}
          end
          constraints, @scope[:constraints] = @scope[:constraints], (@scope[:constraints] || {}).merge(constraints)
          blocks, @scope[:blocks] = @scope[:blocks], (@scope[:blocks] || []) + [block]

          options, @scope[:options] = @scope[:options], (@scope[:options] || {}).merge(options)

          yield

          self
        ensure
          @scope[:path] = path if path_set
          @scope[:name_prefix] = name_prefix if name_prefix_set
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

          if @scope[:name_prefix] && !options[:as].blank?
            options[:as] = "#{@scope[:name_prefix]}_#{options[:as]}"
          elsif @scope[:name_prefix] && options[:as] == ""
            options[:as] = @scope[:name_prefix].to_s
          end

          args.push(options)
          super(*args)
        end
      end

      module Resources
        class Resource #:nodoc:
          attr_reader :plural, :singular

          def initialize(entities, options = {})
            entities = entities.to_s

            @plural   = entities.pluralize
            @singular = entities.singularize
          end

          def name
            plural
          end

          def controller
            plural
          end

          def member_name
            singular
          end

          def collection_name
            plural
          end

          def id_segment
            ":#{singular}_id"
          end
        end

        class SingletonResource < Resource #:nodoc:
          def initialize(entity, options = {})
            super
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

          resource = SingletonResource.new(resources.pop)

          if @scope[:scope_level] == :resources
            nested do
              resource(resource.name, options, &block)
            end
            return self
          end

          scope(:path => resource.name, :controller => resource.controller) do
            with_scope_level(:resource, resource) do
              yield if block_given?

              get "", :to => :show, :as => resource.member_name
              post "", :to => :create
              put "", :to => :update
              delete "", :to => :destroy
              get "new", :to => :new, :as => "new_#{resource.singular}"
              get "edit", :to => :edit, :as => "edit_#{resource.singular}"
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

          resource = Resource.new(resources.pop)

          if @scope[:scope_level] == :resources
            nested do
              resources(resource.name, options, &block)
            end
            return self
          end

          scope(:path => resource.name, :controller => resource.controller) do
            with_scope_level(:resources, resource) do
              yield if block_given?

              with_scope_level(:collection) do
                get "", :to => :index, :as => resource.collection_name
                post "", :to => :create
                get "new", :to => :new, :as => "new_#{resource.singular}"
              end

              with_scope_level(:member) do
                scope(":id") do
                  get "", :to => :show, :as => resource.member_name
                  put "", :to => :update
                  delete "", :to => :destroy
                  get "edit", :to => :edit, :as => "edit_#{resource.singular}"
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
            scope(:name_prefix => parent_resource.collection_name, :as => "") do
              yield
            end
          end
        end

        def member
          unless @scope[:scope_level] == :resources
            raise ArgumentError, "can't use member outside resources scope"
          end

          with_scope_level(:member) do
            scope(":id", :name_prefix => parent_resource.member_name, :as => "") do
              yield
            end
          end
        end

        def nested
          unless @scope[:scope_level] == :resources
            raise ArgumentError, "can't use nested outside resources scope"
          end

          with_scope_level(:nested) do
            scope(parent_resource.id_segment, :name_prefix => parent_resource.member_name) do
              yield
            end
          end
        end

        def match(*args)
          options = args.extract_options!

          if args.length > 1
            args.each { |path| match(path, options) }
            return self
          end

          if args.first.is_a?(Symbol)
            begin
              old_name_prefix, @scope[:name_prefix] = @scope[:name_prefix], "#{args.first}_#{@scope[:name_prefix]}"
              return match(args.first.to_s, options.merge(:to => args.first.to_sym))
            ensure
              @scope[:name_prefix] = old_name_prefix
            end
          end

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

        protected
          def parent_resource
            @scope[:scope_level_resource]
          end

        private
          def with_scope_level(kind, resource = parent_resource)
            old, @scope[:scope_level] = @scope[:scope_level], kind
            old_resource, @scope[:scope_level_resource] = @scope[:scope_level_resource], resource
            yield
          ensure
            @scope[:scope_level] = old
            @scope[:scope_level_resource] = old_resource
          end
      end

      include Base
      include HttpHelpers
      include Scoping
      include Resources
    end
  end
end
