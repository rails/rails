require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/object/blank'

module ActionDispatch
  module Routing
    class Mapper
      class Constraints #:nodoc:
        def self.new(app, constraints, request = Rack::Request)
          if constraints.any?
            super(app, constraints, request)
          else
            app
          end
        end

        attr_reader :app

        def initialize(app, constraints, request)
          @app, @constraints, @request = app, constraints, request
        end

        def call(env)
          req = @request.new(env)

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

      class Mapping #:nodoc:
        IGNORE_OPTIONS = [:to, :as, :via, :on, :constraints, :defaults, :only, :except, :anchor, :shallow, :shallow_path, :shallow_prefix]

        def initialize(set, scope, args)
          @set, @scope    = set, scope
          @path, @options = extract_path_and_options(args)
          normalize_options!
        end

        def to_route
          [ app, conditions, requirements, defaults, @options[:as], @options[:anchor] ]
        end

        private
          def extract_path_and_options(args)
            options = args.extract_options!

            if using_to_shorthand?(args, options)
              path, to = options.find { |name, value| name.is_a?(String) }
              options.merge!(:to => to).delete(path) if path
            else
              path = args.first
            end

            if path.match(':controller')
              raise ArgumentError, ":controller segment is not allowed within a namespace block" if @scope[:module]

              # Add a default constraint for :controller path segments that matches namespaced
              # controllers with default routes like :controller/:action/:id(.:format), e.g:
              # GET /admin/products/show/1
              # => { :controller => 'admin/products', :action => 'show', :id => '1' }
              options.reverse_merge!(:controller => /.+?/)
            end

            [ normalize_path(path), options ]
          end

          def normalize_options!
            path_without_format = @path.sub(/\(\.:format\)$/, '')

            if using_match_shorthand?(path_without_format, @options)
              to_shorthand    = @options[:to].blank?
              @options[:to] ||= path_without_format[1..-1].sub(%r{/([^/]*)$}, '#\1')
              @options[:as] ||= path_without_format[1..-1].gsub("/", "_")
            end

            @options.merge!(default_controller_and_action(to_shorthand))
          end

          # match "account" => "account#index"
          def using_to_shorthand?(args, options)
            args.empty? && options.present?
          end

          # match "account/overview"
          def using_match_shorthand?(path, options)
            path && options.except(:via, :anchor, :to, :as).empty? && path =~ %r{^/[\w\/]+$}
          end

          def normalize_path(path)
            raise ArgumentError, "path is required" if @scope[:path].blank? && path.blank?
            Mapper.normalize_path("#{@scope[:path]}/#{path}")
          end

          def app
            Constraints.new(
              to.respond_to?(:call) ? to : Routing::RouteSet::Dispatcher.new(:defaults => defaults),
              blocks,
              @set.request_class
            )
          end

          def conditions
            { :path_info => @path }.merge(constraints).merge(request_method_condition)
          end

          def requirements
            @requirements ||= (@options[:constraints].is_a?(Hash) ? @options[:constraints] : {}).tap do |requirements|
              requirements.reverse_merge!(@scope[:constraints]) if @scope[:constraints]
              @options.each { |k, v| requirements[k] = v if v.is_a?(Regexp) }
            end
          end

          def defaults
            @defaults ||= (@options[:defaults] || {}).tap do |defaults|
              defaults.reverse_merge!(@scope[:defaults]) if @scope[:defaults]
              @options.each { |k, v| defaults[k] = v unless v.is_a?(Regexp) || IGNORE_OPTIONS.include?(k.to_sym) }
            end
          end

          def default_controller_and_action(to_shorthand=nil)
            if to.respond_to?(:call)
              { }
            else
              if to.is_a?(String)
                controller, action = to.split('#')
              elsif to.is_a?(Symbol)
                action = to.to_s
              end

              controller ||= default_controller
              action     ||= default_action

              unless controller.is_a?(Regexp) || to_shorthand
                controller = [@scope[:module], controller].compact.join("/").presence
              end

              controller = controller.to_s unless controller.is_a?(Regexp)
              action     = action.to_s     unless action.is_a?(Regexp)

              if controller.blank? && segment_keys.exclude?("controller")
                raise ArgumentError, "missing :controller"
              end

              if action.blank? && segment_keys.exclude?("action")
                raise ArgumentError, "missing :action"
              end

              { :controller => controller, :action => action }.tap do |hash|
                hash.delete(:controller) if hash[:controller].blank?
                hash.delete(:action)     if hash[:action].blank?
              end
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
            if @options[:controller]
              @options[:controller]
            elsif @scope[:controller]
              @scope[:controller]
            end
          end

          def default_action
            if @options[:action]
              @options[:action]
            elsif @scope[:action]
              @scope[:action]
            end
          end
      end

      # Invokes Rack::Mount::Utils.normalize path and ensure that
      # (:locale) becomes (/:locale) instead of /(:locale). Except
      # for root cases, where the latter is the correct one.
      def self.normalize_path(path)
        path = Rack::Mount::Utils.normalize_path(path)
        path.gsub!(%r{/(\(+)/?}, '\1/') unless path =~ %r{^/\(+[^/]+\)$}
        path
      end

      module Base
        def initialize(set) #:nodoc:
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

            params = [req.symbolized_path_parameters]
            params << req if path_proc.arity > 1

            uri = URI.parse(path_proc.call(*params))
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
        def initialize(*args) #:nodoc:
          @scope = {}
          super
        end

        def scope(*args)
          options = args.extract_options!
          options = options.dup

          if name_prefix = options.delete(:name_prefix)
            options[:as] ||= name_prefix
            ActiveSupport::Deprecation.warn ":name_prefix was deprecated in the new router syntax. Use :as instead.", caller
          end

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

        def namespace(path, options = {})
          path = path.to_s
          options = { :path => path, :as => path, :module => path,
                      :shallow_path => path, :shallow_prefix => path }.merge!(options)
          scope(options) { yield }
        end

        def constraints(constraints = {})
          scope(:constraints => constraints) { yield }
        end

        def defaults(defaults = {})
          scope(:defaults => defaults) { yield }
        end

        def match(*args)
          options = args.extract_options!

          options = (@scope[:options] || {}).merge(options)

          if @scope[:as] && !options[:as].blank?
            options[:as] = "#{@scope[:as]}_#{options[:as]}"
          elsif @scope[:as] && options[:as] == ""
            options[:as] = @scope[:as].to_s
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
            (parent || {}).except(*override_keys(child)).merge(child)
          end

          def merge_shallow_scope(parent, child)
            child ? true : false
          end

          def override_keys(child)
            child.key?(:only) || child.key?(:except) ? [:only, :except] : []
          end
      end

      module Resources
        # CANONICAL_ACTIONS holds all actions that does not need a prefix or
        # a path appended since they fit properly in their scope level.
        VALID_ON_OPTIONS = [:new, :collection, :member]
        CANONICAL_ACTIONS = [:index, :create, :new, :show, :update, :destroy]
        RESOURCE_OPTIONS = [:as, :controller, :path, :only, :except]

        class Resource #:nodoc:
          DEFAULT_ACTIONS = [:index, :create, :new, :show, :update, :destroy, :edit]

          attr_reader :controller, :path, :options

          def initialize(entities, options = {})
            @name       = entities.to_s
            @path       = options.delete(:path) || @name
            @controller = (options.delete(:controller) || @name).to_s
            @as         = options.delete(:as)
            @options    = options
          end

          def default_actions
            self.class::DEFAULT_ACTIONS
          end

          def actions
            if only = @options[:only]
              Array(only).map(&:to_sym)
            elsif except = @options[:except]
              default_actions - Array(except).map(&:to_sym)
            else
              default_actions
            end
          end

          def name
            @as || @name
          end

          def plural
            name.to_s.pluralize
          end

          def singular
            name.to_s.singularize
          end

          def member_name
            singular
          end

          # Checks for uncountable plurals, and appends "_index" if they're.
          def collection_name
            singular == plural ? "#{plural}_index" : plural
          end

          def resource_scope
            { :controller => controller }
          end

          def collection_scope
            path
          end

          def member_scope
            "#{path}/:id"
          end

          def new_scope(new_path)
            "#{path}/#{new_path}"
          end

          def nested_scope
            "#{path}/:#{singular}_id"
          end

        end

        class SingletonResource < Resource #:nodoc:
          DEFAULT_ACTIONS = [:show, :create, :update, :destroy, :new, :edit]

          def initialize(entities, options)
            @name       = entities.to_s
            @path       = options.delete(:path) || @name
            @controller = (options.delete(:controller) || plural).to_s
            @as         = options.delete(:as)
            @options    = options
          end

          def member_name
            name
          end
          alias :collection_name :member_name

          def member_scope
            path
          end
          alias :nested_scope :member_scope
        end

        def initialize(*args) #:nodoc:
          super
          @scope[:path_names] = @set.resources_path_names
        end

        def resources_path_names(options)
          @scope[:path_names].merge!(options)
        end

        def resource(*resources, &block)
          options = resources.extract_options!

          if apply_common_behavior_for(:resource, resources, options, &block)
            return self
          end

          resource_scope(SingletonResource.new(resources.pop, options)) do
            yield if block_given?

            collection_scope do
              post :create
            end if parent_resource.actions.include?(:create)

            new_scope do
              get :new
            end if parent_resource.actions.include?(:new)

            member_scope  do
              get    :show if parent_resource.actions.include?(:show)
              put    :update if parent_resource.actions.include?(:update)
              delete :destroy if parent_resource.actions.include?(:destroy)
              get    :edit if parent_resource.actions.include?(:edit)
            end
          end

          self
        end

        def resources(*resources, &block)
          options = resources.extract_options!

          if apply_common_behavior_for(:resources, resources, options, &block)
            return self
          end

          resource_scope(Resource.new(resources.pop, options)) do
            yield if block_given?

            collection_scope do
              get  :index if parent_resource.actions.include?(:index)
              post :create if parent_resource.actions.include?(:create)
            end

            new_scope do
              get :new
            end if parent_resource.actions.include?(:new)

            member_scope  do
              get    :show if parent_resource.actions.include?(:show)
              put    :update if parent_resource.actions.include?(:update)
              delete :destroy if parent_resource.actions.include?(:destroy)
              get    :edit if parent_resource.actions.include?(:edit)
            end
          end

          self
        end

        def collection
          unless @scope[:scope_level] == :resources
            raise ArgumentError, "can't use collection outside resources scope"
          end

          collection_scope do
            yield
          end
        end

        def member
          unless resource_scope?
            raise ArgumentError, "can't use member outside resource(s) scope"
          end

          member_scope do
            yield
          end
        end

        def new
          unless resource_scope?
            raise ArgumentError, "can't use new outside resource(s) scope"
          end

          new_scope do
            yield
          end
        end

        def nested
          unless resource_scope?
            raise ArgumentError, "can't use nested outside resource(s) scope"
          end

          with_scope_level(:nested) do
            if shallow?
              with_exclusive_scope do
                if @scope[:shallow_path].blank?
                  scope(parent_resource.nested_scope, nested_options) { yield }
                else
                  scope(@scope[:shallow_path], :as => @scope[:shallow_prefix]) do
                    scope(parent_resource.nested_scope, nested_options) { yield }
                  end
                end
              end
            else
              scope(parent_resource.nested_scope, nested_options) { yield }
            end
          end
        end

        def namespace(path, options = {})
          if resource_scope?
            nested { super }
          else
            super
          end
        end

        def shallow
          scope(:shallow => true) do
            yield
          end
        end

        def shallow?
          parent_resource.instance_of?(Resource) && @scope[:shallow]
        end

        def match(*args)
          options = args.extract_options!.dup
          options[:anchor] = true unless options.key?(:anchor)

          if args.length > 1
            args.each { |path| match(path, options.dup) }
            return self
          end

          on = options.delete(:on)
          if VALID_ON_OPTIONS.include?(on)
            args.push(options)
            return send(on){ match(*args) }
          elsif on
            raise ArgumentError, "Unknown scope #{on.inspect} given to :on"
          end

          if @scope[:scope_level] == :resource
            args.push(options)
            return member { match(*args) }
          end

          path = options.delete(:path)
          action = args.first

          if action.is_a?(Symbol)
            path = path_for_action(action, path)
            options[:to] ||= action
            options[:as]   = name_for_action(action, options[:as])

            with_exclusive_scope do
              return super(path, options)
            end
          elsif resource_method_scope?
            path = path_for_custom_action
            options[:as] = name_for_action(options[:as]) if options[:as]
            args.push(options)

            with_exclusive_scope do
              scope(path) do
                return super
              end
            end
          end

          if resource_scope?
            raise ArgumentError, "can't define route directly in resource(s) scope"
          end

          args.push(options)
          super
        end

        def root(options={})
          if @scope[:scope_level] == :resources
            with_scope_level(:nested) do
              scope(parent_resource.path, :as => parent_resource.collection_name) do
                super(options)
              end
            end
          else
            super(options)
          end
        end

        protected

          def parent_resource #:nodoc:
            @scope[:scope_level_resource]
          end

          def apply_common_behavior_for(method, resources, options, &block)
            if resources.length > 1
              resources.each { |r| send(method, r, options, &block) }
              return true
            end

            scope_options = options.slice!(*RESOURCE_OPTIONS)
            unless scope_options.empty?
              scope(scope_options) do
                send(method, resources.pop, options, &block)
              end
              return true
            end

            unless action_options?(options)
              options.merge!(scope_action_options) if scope_action_options?
            end

            if resource_scope?
              nested do
                send(method, resources.pop, options, &block)
              end
              return true
            end

            false
          end

          def action_options?(options)
            options[:only] || options[:except]
          end

          def scope_action_options?
            @scope[:options].is_a?(Hash) && (@scope[:options][:only] || @scope[:options][:except])
          end

          def scope_action_options
            @scope[:options].slice(:only, :except)
          end

          def resource_scope?
            [:resource, :resources].include?(@scope[:scope_level])
          end

          def resource_method_scope?
            [:collection, :member, :new].include?(@scope[:scope_level])
          end

          def with_exclusive_scope
            begin
              old_name_prefix, old_path = @scope[:as], @scope[:path]
              @scope[:as], @scope[:path] = nil, nil

              with_scope_level(:exclusive) do
                yield
              end
            ensure
              @scope[:as], @scope[:path] = old_name_prefix, old_path
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

          def resource_scope(resource)
            with_scope_level(resource.is_a?(SingletonResource) ? :resource : :resources, resource) do
              scope(parent_resource.resource_scope) do
                yield
              end
            end
          end

          def new_scope
            with_scope_level(:new) do
              scope(parent_resource.new_scope(action_path(:new))) do
                yield
              end
            end
          end

          def collection_scope
            with_scope_level(:collection) do
              scope(parent_resource.collection_scope) do
                yield
              end
            end
          end

          def member_scope
            with_scope_level(:member) do
              scope(parent_resource.member_scope) do
                yield
              end
            end
          end

          def nested_options
            {}.tap do |options|
              options[:as] = parent_resource.member_name
              options[:constraints] = { "#{parent_resource.singular}_id".to_sym => id_constraint } if id_constraint?
            end
          end

          def id_constraint?
            @scope[:id].is_a?(Regexp) || (@scope[:constraints] && @scope[:constraints][:id].is_a?(Regexp))
          end

          def id_constraint
            @scope[:id] || @scope[:constraints][:id]
          end

          def canonical_action?(action, flag)
            flag && CANONICAL_ACTIONS.include?(action)
          end

          def shallow_scoping?
            shallow? && @scope[:scope_level] == :member
          end

          def path_for_action(action, path)
            prefix = shallow_scoping? ?
              "#{@scope[:shallow_path]}/#{parent_resource.path}/:id" : @scope[:path]

            if canonical_action?(action, path.blank?)
              "#{prefix}(.:format)"
            else
              "#{prefix}/#{action_path(action, path)}(.:format)"
            end
          end

          def path_for_custom_action
            if shallow_scoping?
              "#{@scope[:shallow_path]}/#{parent_resource.path}/:id"
            else
              @scope[:path]
            end
          end

          def action_path(name, path = nil)
            path || @scope[:path_names][name.to_sym] || name.to_s
          end

          def prefix_name_for_action(action, as)
            if as.present?
              "#{as}_"
            elsif as
              ""
            elsif !canonical_action?(action, @scope[:scope_level])
              "#{action}_"
            end
          end

          def name_for_action(action, as=nil)
            prefix = prefix_name_for_action(action, as)
            name_prefix = @scope[:as]

            if parent_resource
              collection_name = parent_resource.collection_name
              member_name = parent_resource.member_name
              name_prefix = "#{name_prefix}_" if name_prefix.present?
            end

            case @scope[:scope_level]
            when :collection
              "#{prefix}#{name_prefix}#{collection_name}"
            when :new
              "#{prefix}new_#{name_prefix}#{member_name}"
            else
              if shallow_scoping?
                shallow_prefix = "#{@scope[:shallow_prefix]}_" if @scope[:shallow_prefix].present?
                "#{prefix}#{shallow_prefix}#{member_name}"
              else
                "#{prefix}#{name_prefix}#{member_name}"
              end
            end
          end
      end

      include Base
      include HttpHelpers
      include Scoping
      include Resources
    end
  end
end
