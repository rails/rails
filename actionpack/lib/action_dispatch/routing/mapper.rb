module ActionDispatch
  module Routing
    class Mapper
      class Constraints
        def self.new(app, constraints = [])
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
              return [ 404, {'X-Cascade' => 'pass'}, [] ]
            elsif constraint.respond_to?(:call) && !constraint.call(req)
              return [ 404, {'X-Cascade' => 'pass'}, [] ]
            end
          }

          @app.call(env)
        end
      end

      class Mapping
        def initialize(set, scope, args)
          @set, @scope    = set, scope
          @path, @options = extract_path_and_options(args)
        end

        def to_route
          [ app, conditions, requirements, defaults, @options[:as] ]
        end

        private
          def extract_path_and_options(args)
            options = args.extract_options!

            case
            when using_to_shorthand?(args, options)
              path, to = options.find { |name, value| name.is_a?(String) }
              options.merge!(:to => to).delete(path) if path
            when using_match_shorthand?(args, options)
              path = args.first
              options = { :to => path.gsub("/", "#"), :as => path.gsub("/", "_") }
            else
              path = args.first
            end

            [ normalize_path(path), options ]
          end

          # match "account" => "account#index"
          def using_to_shorthand?(args, options)
            args.empty? && options.present?
          end

          # match "account/overview"
          def using_match_shorthand?(args, options)
            args.present? && options.except(:via).empty? && !args.first.include?(':')
          end

          def normalize_path(path)
            path = nil if path == ""
            path = "#{@scope[:path]}#{path}" if @scope[:path]
            path = Rack::Mount::Utils.normalize_path(path) if path

            raise ArgumentError, "path is required" unless path

            path
          end


          def app
            Constraints.new(
              to.respond_to?(:call) ? to : Routing::RouteSet::Dispatcher.new(:defaults => defaults),
              blocks
            )
          end

          def conditions
            { :path_info => @path }.merge(constraints).merge(request_method_condition)
          end

          def requirements
            @requirements ||= returning(@options[:constraints] || {}) do |requirements|
              requirements.reverse_merge!(@scope[:constraints]) if @scope[:constraints]
              @options.each { |k, v| requirements[k] = v if v.is_a?(Regexp) }
              requirements[:controller] ||= @set.controller_constraints
            end
          end

          def defaults
            @defaults ||= if to.respond_to?(:call)
              { }
            else
              defaults = case to
              when String
                controller, action = to.split('#')
                { :controller => controller, :action => action }
              when Symbol
                { :action => to.to_s }.merge(default_controller ? { :controller => default_controller } : {})
              else
                default_controller ? { :controller => default_controller } : {}
              end

              if defaults[:controller].blank? && segment_keys.exclude?("controller")
                raise ArgumentError, "missing :controller"
              end

              if defaults[:action].blank? && segment_keys.exclude?("action")
                raise ArgumentError, "missing :action"
              end

              defaults
            end
          end


          def blocks
            if @options[:constraints].present? && !@options[:constraints].is_a?(Hash)
              block = @options[:constraints]
            else
              block = nil
            end

            ((@scope[:blocks] || []) + [ block ]).compact
          end

          def constraints
            @constraints ||= requirements.reject { |k, v| segment_keys.include?(k.to_s) || k == :controller }
          end

          def request_method_condition
            if via = @options[:via]
              via = Array(via).map { |m| m.to_s.upcase }
              { :request_method => Regexp.union(*via) }
            else
              { }
            end
          end

          def segment_keys
            @segment_keys ||= Rack::Mount::RegexpWithNamedGroups.new(
                Rack::Mount::Strexp.compile(@path, requirements, SEPARATORS)
              ).names
          end

          def to
            @options[:to]
          end

          def default_controller
            @scope[:controller].to_s if @scope[:controller]
          end
      end

      module Base
        def initialize(set)
          @set = set
        end

        def root(options = {})
          match '/', options.reverse_merge(:as => :root)
        end

        def match(*args)
          @set.add_route(*Mapping.new(@set, @scope, args).to_route)
          self
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

        def redirect(*args, &block)
          options = args.last.is_a?(Hash) ? args.pop : {}

          path      = args.shift || block
          path_proc = path.is_a?(Proc) ? path : proc { |params| path % params }
          status    = options[:status] || 301

          lambda do |env|
            req    = Rack::Request.new(env)
            params = path_proc.call(env["action_dispatch.request.path_parameters"])
            url    = req.scheme + '://' + req.host + params

            [ status, {'Location' => url, 'Content-Type' => 'text/html'}, ['Moved Permanently'] ]
          end
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
            path, @scope[:path] = @scope[:path], Rack::Mount::Utils.normalize_path(@scope[:path].to_s + path.to_s)
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
          @scope[:path]        = path        if path_set
          @scope[:name_prefix] = name_prefix if name_prefix_set
          @scope[:controller]  = controller  if controller_set
          @scope[:options]     = options
          @scope[:blocks]      = blocks
          @scope[:constraints] = constraints
        end

        def controller(controller)
          scope(controller.to_sym) { yield }
        end

        def namespace(path)
          scope("/#{path}") { yield }
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

          scope(:path => "/#{resource.name}", :controller => resource.controller) do
            with_scope_level(:resource, resource) do
              yield if block_given?

              get    "(.:format)",      :to => :show, :as => resource.member_name
              post   "(.:format)",      :to => :create
              put    "(.:format)",      :to => :update
              delete "(.:format)",      :to => :destroy
              get    "/new(.:format)",  :to => :new,  :as => "new_#{resource.singular}"
              get    "/edit(.:format)", :to => :edit, :as => "edit_#{resource.singular}"
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

          scope(:path => "/#{resource.name}", :controller => resource.controller) do
            with_scope_level(:resources, resource) do
              yield if block_given?

              with_scope_level(:collection) do
                get  "(.:format)", :to => :index, :as => resource.collection_name
                post "(.:format)", :to => :create

                with_exclusive_name_prefix :new do
                  get "/new(.:format)", :to => :new, :as => resource.singular
                end
              end

              with_scope_level(:member) do
                scope("/:id") do
                  get    "(.:format)", :to => :show, :as => resource.member_name
                  put    "(.:format)", :to => :update
                  delete "(.:format)", :to => :destroy

                  with_exclusive_name_prefix :edit do
                    get "/edit(.:format)", :to => :edit, :as => resource.singular
                  end
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
            scope("/:id", :name_prefix => parent_resource.member_name, :as => "") do
              yield
            end
          end
        end

        def nested
          unless @scope[:scope_level] == :resources
            raise ArgumentError, "can't use nested outside resources scope"
          end

          with_scope_level(:nested) do
            scope("/#{parent_resource.id_segment}", :name_prefix => parent_resource.member_name) do
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
            with_exclusive_name_prefix(args.first) do
              return match("/#{args.first}(.:format)", options.merge(:to => args.first.to_sym))
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
          def with_exclusive_name_prefix(prefix)
            begin
              old_name_prefix = @scope[:name_prefix]

              if !old_name_prefix.blank?
                @scope[:name_prefix] = "#{prefix}_#{@scope[:name_prefix]}"
              else
                @scope[:name_prefix] = prefix.to_s
              end

              yield
            ensure
              @scope[:name_prefix] = old_name_prefix
            end
          end

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
