require 'active_support/core_ext/hash/except'

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
          [ app, conditions, requirements, defaults, @options[:as], @options[:anchor] ]
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
            args.present? && options.except(:via, :anchor).empty? && !args.first.include?(':')
          end

          def normalize_path(path)
            path = "#{@scope[:path]}/#{path}"
            raise ArgumentError, "path is required" if path.empty?
            Mapper.normalize_path(path)
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
            @requirements ||= (@options[:constraints] || {}).tap do |requirements|
              requirements.reverse_merge!(@scope[:constraints]) if @scope[:constraints]
              @options.each { |k, v| requirements[k] = v if v.is_a?(Regexp) }
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

      # Invokes Rack::Mount::Utils.normalize path and ensure that
      # (:locale) becomes (/:locale) instead of /(:locale). Except
      # for root cases, where the latter is the correct one.
      def self.normalize_path(path)
        path = Rack::Mount::Utils.normalize_path(path)
        path.sub!(%r{/(\(+)/?:}, '\1/:') unless path =~ %r{^/\(+:.*\)$}
        path
      end

      module Base
        def initialize(set)
          @set = set
        end

        def root(options = {})
          match '/', options.reverse_merge(:as => :root)
        end

        def match(*args)
          mapping = Mapping.new(@set, @scope, args).to_route
          @set.add_route(*mapping)
          self
        end

        def default_url_options=(options)
          @set.default_url_options = options
        end
        alias_method :default_url_options, :default_url_options=
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
          body      = 'Moved Permanently'

          lambda do |env|
            req = Request.new(env)
            uri = URI.parse(path_proc.call(req.symbolized_path_parameters))
            uri.scheme ||= req.scheme
            uri.host   ||= req.host
            uri.port   ||= req.port unless req.port == 80

            headers = {
              'Location' => uri.to_s,
              'Content-Type' => 'text/html',
              'Content-Length' => body.length.to_s
            }
            [ status, headers, [body] ]
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

          recover = {}

          options[:constraints] ||= {}
          unless options[:constraints].is_a?(Hash)
            block, options[:constraints] = options[:constraints], {}
          end

          scope_options.each do |option|
            if value = options.delete(option)
              recover[option] = @scope[option]
              @scope[option]  = send("merge_#{option}_scope", @scope[option], value)
            end
          end

          recover[:block] = @scope[:blocks]
          @scope[:blocks] = merge_blocks_scope(@scope[:blocks], block)

          recover[:options] = @scope[:options]
          @scope[:options]  = merge_options_scope(@scope[:options], options)

          yield
          self
        ensure
          scope_options.each do |option|
            @scope[option] = recover[option] if recover.has_key?(option)
          end

          @scope[:options] = recover[:options]
          @scope[:blocks]  = recover[:block]
        end

        def controller(controller)
          scope(controller.to_sym) { yield }
        end

        def namespace(path)
          scope(path.to_s, :name_prefix => path.to_s, :controller_namespace => path.to_s) { yield }
        end

        def constraints(constraints = {})
          scope(:constraints => constraints) { yield }
        end

        def match(*args)
          options = args.extract_options!

          options = (@scope[:options] || {}).merge(options)
          options[:anchor] = true unless options.key?(:anchor)

          if @scope[:name_prefix] && !options[:as].blank?
            options[:as] = "#{@scope[:name_prefix]}_#{options[:as]}"
          elsif @scope[:name_prefix] && options[:as] == ""
            options[:as] = @scope[:name_prefix].to_s
          end

          args.push(options)
          super(*args)
        end

        private
          def scope_options
            @scope_options ||= private_methods.grep(/^merge_(.+)_scope$/) { $1.to_sym }
          end

          def merge_path_scope(parent, child)
            Mapper.normalize_path("#{parent}/#{child}")
          end

          def merge_name_prefix_scope(parent, child)
            parent ? "#{parent}_#{child}" : child
          end

          def merge_controller_namespace_scope(parent, child)
            parent ? "#{parent}/#{child}" : child
          end

          def merge_controller_scope(parent, child)
            @scope[:controller_namespace] ? "#{@scope[:controller_namespace]}/#{child}" : child
          end

          def merge_resources_path_names_scope(parent, child)
            merge_options_scope(parent, child)
          end

          def merge_constraints_scope(parent, child)
            merge_options_scope(parent, child)
          end

          def merge_blocks_scope(parent, child)
            (parent || []) + [child]
          end

          def merge_options_scope(parent, child)
            (parent || {}).merge(child)
          end
      end

      module Resources
        CRUD_ACTIONS = [:index, :show, :create, :update, :destroy]

        class Resource #:nodoc:
          def self.default_actions
            [:index, :create, :new, :show, :update, :destroy, :edit]
          end

          attr_reader :plural, :singular, :options

          def initialize(entities, options = {})
            @name = entities.to_s
            @options = options

            @plural   = @name.pluralize
            @singular = @name.singularize
          end

          def default_actions
            self.class.default_actions
          end

          def actions
            if only = options[:only]
              Array(only).map(&:to_sym)
            elsif except = options[:except]
              default_actions - Array(except).map(&:to_sym)
            else
              default_actions
            end
          end

          def action_type(action)
            case action
            when :index, :create
              :collection
            when :show, :update, :destroy
              :member
            end
          end

          def name
            options[:as] || @name
          end

          def controller
            options[:controller] || plural
          end

          def member_name
            singular
          end

          def collection_name
            plural
          end

          def name_for_action(action)
            case action_type(action)
            when :collection
              collection_name
            when :member
              member_name
            end
          end

          def id_segment
            ":#{singular}_id"
          end
        end

        class SingletonResource < Resource #:nodoc:
          def self.default_actions
            [:show, :create, :update, :destroy, :new, :edit]
          end

          def initialize(entity, options = {})
            super
          end

          def action_type(action)
            case action
            when :show, :create, :update, :destroy
              :member
            end
          end

          def member_name
            name
          end
        end

        def initialize(*args)
          super
          @scope[:resources_path_names] = @set.resources_path_names
        end

        def resource(*resources, &block)
          options = resources.extract_options!

          if apply_common_behavior_for(:resource, resources, options, &block)
            return self
          end

          resource = SingletonResource.new(resources.pop, options)

          scope(:path => resource.name.to_s, :controller => resource.controller) do
            with_scope_level(:resource, resource) do

              scope(:name_prefix => resource.name.to_s) do
                yield if block_given?
              end

              get    :show if resource.actions.include?(:show)
              post   :create if resource.actions.include?(:create)
              put    :update if resource.actions.include?(:update)
              delete :destroy if resource.actions.include?(:destroy)
              get    :new, :as => resource.name if resource.actions.include?(:new)
              get    :edit, :as => resource.name if resource.actions.include?(:edit)
            end
          end

          self
        end

        def resources(*resources, &block)
          options = resources.extract_options!

          if apply_common_behavior_for(:resources, resources, options, &block)
            return self
          end

          resource = Resource.new(resources.pop, options)

          scope(:path => resource.name.to_s, :controller => resource.controller) do
            with_scope_level(:resources, resource) do
              yield if block_given?

              with_scope_level(:collection) do
                get  :index if resource.actions.include?(:index)
                post :create if resource.actions.include?(:create)
                get  :new, :as => resource.singular if resource.actions.include?(:new)
              end

              with_scope_level(:member) do
                scope(':id') do
                  get    :show if resource.actions.include?(:show)
                  put    :update if resource.actions.include?(:update)
                  delete :destroy if resource.actions.include?(:destroy)
                  get    :edit, :as => resource.singular if resource.actions.include?(:edit)
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
            scope(':id', :name_prefix => parent_resource.member_name, :as => "") do
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

        def mount(app, options = nil)
          if options
            path = options.delete(:at)
          else
            options = app
            app, path = options.find { |k, v| k.respond_to?(:call) }
            options.delete(app) if app
          end

          raise "A rack application must be specified" unless path

          match(path, options.merge(:to => app, :anchor => false))
          self
        end

        def match(*args)
          options = args.extract_options!

          if args.length > 1
            args.each { |path| match(path, options) }
            return self
          end

          resources_path_names = options.delete(:path_names)

          if args.first.is_a?(Symbol)
            action = args.first
            if CRUD_ACTIONS.include?(action)
              begin
                old_path = @scope[:path]
                @scope[:path] = "#{@scope[:path]}(.:format)"
                return match(options.reverse_merge(
                  :to => action,
                  :as => parent_resource.name_for_action(action)
                ))
              ensure
                @scope[:path] = old_path
              end
            else
              with_exclusive_name_prefix(action) do
                return match("#{action_path(action, resources_path_names)}(.:format)", options.reverse_merge(:to => action))
              end
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
          def action_path(name, path_names = nil)
            path_names ||= @scope[:resources_path_names]
            path_names[name.to_sym] || name.to_s
          end

          def apply_common_behavior_for(method, resources, options, &block)
            if resources.length > 1
              resources.each { |r| send(method, r, options, &block) }
              return true
            end

            if path_names = options.delete(:path_names)
              scope(:resources_path_names => path_names) do
                send(method, resources.pop, options, &block)
              end
              return true
            end

            if @scope[:scope_level] == :resources
              nested do
                send(method, resources.pop, options, &block)
              end
              return true
            end

            false
          end

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
