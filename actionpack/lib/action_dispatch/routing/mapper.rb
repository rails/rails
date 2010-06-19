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
        IGNORE_OPTIONS = [:to, :as, :controller, :action, :via, :on, :constraints, :defaults, :only, :except, :anchor, :shallow, :shallow_path, :shallow_prefix]

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

            if using_to_shorthand?(args, options)
              path, to = options.find { |name, value| name.is_a?(String) }
              options.merge!(:to => to).delete(path) if path
            else
              path = args.first
            end

            if @scope[:module] && options[:to]
              if options[:to].to_s.include?("#")
                options[:to] = "#{@scope[:module]}/#{options[:to]}"
              elsif @scope[:controller].nil?
                options[:to] = "#{@scope[:module]}##{options[:to]}"
              end
            end

            path = normalize_path(path)
            path_without_format = path.sub(/\(\.:format\)$/, '')

            if using_match_shorthand?(path_without_format, options)
              options[:to] ||= path_without_format[1..-1].sub(%r{/([^/]*)$}, '#\1')
              options[:as] ||= path_without_format[1..-1].gsub("/", "_")
            end

            [ path, options ]
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
              defaults.merge!(default_controller_and_action)
              defaults.reverse_merge!(@scope[:defaults]) if @scope[:defaults]
              @options.each { |k, v| defaults[k] = v unless v.is_a?(Regexp) || IGNORE_OPTIONS.include?(k.to_sym) }
            end
          end

          def default_controller_and_action
            if to.respond_to?(:call)
              { }
            else
              defaults = case to
              when String
                controller, action = to.split('#')
                { :controller => controller, :action => action }
              when Symbol
                { :action => to.to_s }
              else
                {}
              end

              defaults[:controller] ||= default_controller

              defaults.delete(:controller) if defaults[:controller].blank?
              defaults.delete(:action)     if defaults[:action].blank?

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
            if @options[:controller]
              @options[:controller].to_s
            elsif @scope[:controller]
              @scope[:controller].to_s
            end
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
          path = path.to_s
          scope(:path => path, :name_prefix => path, :module => path, :shallow_path => path, :shallow_prefix => path) { yield }
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

          def merge_shallow_path_scope(parent, child)
            Mapper.normalize_path("#{parent}/#{child}")
          end

          def merge_name_prefix_scope(parent, child)
            parent ? "#{parent}_#{child}" : child
          end

          def merge_shallow_prefix_scope(parent, child)
            parent ? "#{parent}_#{child}" : child
          end

          def merge_module_scope(parent, child)
            parent ? "#{parent}/#{child}" : child
          end

          def merge_controller_scope(parent, child)
            @scope[:module] ? "#{@scope[:module]}/#{child}" : child
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
            (parent || []) + [child]
          end

          def merge_options_scope(parent, child)
            (parent || {}).merge(child)
          end

          def merge_shallow_scope(parent, child)
            child ? true : false
          end
      end

      module Resources
        class Resource #:nodoc:
          def self.default_actions
            [:index, :create, :new, :show, :update, :destroy, :edit]
          end

          attr_reader :controller, :path, :options

          def initialize(entities, options = {})
            @name       = entities.to_s
            @path       = options.delete(:path) || @name
            @controller = options.delete(:controller) || @name.to_s.pluralize
            @options    = options
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

          def name
            options[:as] || @name
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

          alias_method :nested_name, :member_name

          # Checks for uncountable plurals, and appends "_index" if they're.
          def collection_name
            singular == plural ? "#{plural}_index" : plural
          end

          def shallow?
            options[:shallow] ? true : false
          end

          def constraints
            options[:constraints] || {}
          end

          def id_constraint?
            options[:id] && options[:id].is_a?(Regexp) || constraints[:id] && constraints[:id].is_a?(Regexp)
          end

          def id_constraint
            options[:id] || constraints[:id]
          end

          def collection_options
            (options || {}).dup.tap do |opts|
              opts.delete(:id)
              opts[:constraints] = options[:constraints].dup if options[:constraints]
              opts[:constraints].delete(:id) if options[:constraints].is_a?(Hash)
            end
          end

          def nested_path
            "#{path}/:#{singular}_id"
          end

          def nested_options
            {}.tap do |opts|
              opts[:name_prefix] = member_name
              opts["#{singular}_id".to_sym] = id_constraint if id_constraint?
              opts[:options] = { :shallow => shallow? } unless options[:shallow].nil?
            end
          end

          def resource_scope
            [{ :controller => controller }]
          end

          def collection_scope
            [path, collection_options]
          end

          def member_scope
            ["#{path}/:id", options]
          end

          def new_scope
            [path]
          end

          def nested_scope
            [nested_path, nested_options]
          end
        end

        class SingletonResource < Resource #:nodoc:
          def self.default_actions
            [:show, :create, :update, :destroy, :new, :edit]
          end

          def initialize(entity, options = {})
            super
          end

          def member_name
            name
          end
          alias_method :collection_name, :member_name

          def nested_path
            path
          end

          def nested_options
            {}.tap do |opts|
              opts[:name_prefix] = member_name
              opts[:options] = { :shallow => shallow? } unless @options[:shallow].nil?
            end
          end

          def shallow?
            false
          end

          def member_scope
            [path, options]
          end
        end

        def initialize(*args) #:nodoc:
          super
          @scope[:path_names] = @set.resources_path_names
        end

        def resource(*resources, &block)
          options = resources.extract_options!
          options = (@scope[:options] || {}).merge(options)
          options[:shallow] = true if @scope[:shallow] && !options.has_key?(:shallow)

          if apply_common_behavior_for(:resource, resources, options, &block)
            return self
          end

          resource_scope(SingletonResource.new(resources.pop, options)) do
            yield if block_given?

            collection_scope do
              post :create if parent_resource.actions.include?(:create)
              get  :new if parent_resource.actions.include?(:new)
            end

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
          options = (@scope[:options] || {}).merge(options)
          options[:shallow] = true if @scope[:shallow] && !options.has_key?(:shallow)

          if apply_common_behavior_for(:resources, resources, options, &block)
            return self
          end

          resource_scope(Resource.new(resources.pop, options)) do
            yield if block_given?

            collection_scope do
              get  :index if parent_resource.actions.include?(:index)
              post :create if parent_resource.actions.include?(:create)
              get  :new if parent_resource.actions.include?(:new)
            end

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

          with_scope_level(:new) do
            scope(*parent_resource.new_scope) do
              scope(action_path(:new)) do
                yield
              end
            end
          end
        end

        def nested
          unless resource_scope?
            raise ArgumentError, "can't use nested outside resource(s) scope"
          end

          with_scope_level(:nested) do
            if parent_resource.shallow?
              with_exclusive_scope do
                if @scope[:shallow_path].blank?
                  scope(*parent_resource.nested_scope) { yield }
                else
                  scope(@scope[:shallow_path], :name_prefix => @scope[:shallow_prefix]) do
                    scope(*parent_resource.nested_scope) { yield }
                  end
                end
              end
            else
              scope(*parent_resource.nested_scope) { yield }
            end
          end
        end

        def namespace(path)
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

        def match(*args)
          options = args.extract_options!

          options[:anchor] = true unless options.key?(:anchor)

          if args.length > 1
            args.each { |path| match(path, options.dup) }
            return self
          end

          if [:collection, :member, :new].include?(options[:on])
            args.push(options)

            case options.delete(:on)
            when :collection
              return collection { match(*args) }
            when :member
              return member { match(*args) }
            when :new
              return new { match(*args) }
            end
          end

          if @scope[:scope_level] == :resource
            args.push(options)
            return member { match(*args) }
          end

          path_names = options.delete(:path_names)

          if args.first.is_a?(Symbol)
            path = path_for_action(args.first, path_names)
            options = options_for_action(args.first, options)

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
              scope(parent_resource.path, :name_prefix => parent_resource.collection_name) do
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

        private
          def apply_common_behavior_for(method, resources, options, &block)
            if resources.length > 1
              resources.each { |r| send(method, r, options, &block) }
              return true
            end

            if path_names = options.delete(:path_names)
              scope(:path_names => path_names) do
                send(method, resources.pop, options, &block)
              end
              return true
            end

            if resource_scope?
              nested do
                send(method, resources.pop, options, &block)
              end
              return true
            end

            false
          end

          def resource_scope?
            [:resource, :resources].include?(@scope[:scope_level])
          end

          def resource_method_scope?
            [:collection, :member, :new].include?(@scope[:scope_level])
          end

          def with_exclusive_scope
            begin
              old_name_prefix, old_path = @scope[:name_prefix], @scope[:path]
              @scope[:name_prefix], @scope[:path] = nil, nil

              with_scope_level(:exclusive) do
                yield
              end
            ensure
              @scope[:name_prefix], @scope[:path] = old_name_prefix, old_path
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
              scope(*parent_resource.resource_scope) do
                yield
              end
            end
          end

          def collection_scope
            with_scope_level(:collection) do
              scope(*parent_resource.collection_scope) do
                yield
              end
            end
          end

          def member_scope
            with_scope_level(:member) do
              scope(*parent_resource.member_scope) do
                yield
              end
            end
          end

          def path_for_action(action, path_names)
            case action
            when :index, :create
              "#{@scope[:path]}(.:format)"
            when :show, :update, :destroy
              if parent_resource.shallow?
                "#{@scope[:shallow_path]}/#{parent_resource.path}/:id(.:format)"
              else
                "#{@scope[:path]}(.:format)"
              end
            when :new
              "#{@scope[:path]}/#{action_path(:new)}(.:format)"
            when :edit
              if parent_resource.shallow?
                "#{@scope[:shallow_path]}/#{parent_resource.path}/:id/#{action_path(:edit)}(.:format)"
              else
                "#{@scope[:path]}/#{action_path(:edit)}(.:format)"
              end
            else
              case @scope[:scope_level]
              when :collection, :new
                "#{@scope[:path]}/#{action_path(action)}(.:format)"
              else
                if parent_resource.shallow?
                  "#{@scope[:shallow_path]}/#{parent_resource.path}/:id/#{action_path(action)}(.:format)"
                else
                  "#{@scope[:path]}/#{action_path(action)}(.:format)"
                end
              end
            end
          end

          def path_for_custom_action
            case @scope[:scope_level]
            when :collection, :new
              @scope[:path]
            else
              if parent_resource.shallow?
                "#{@scope[:shallow_path]}/#{parent_resource.path}/:id"
              else
                @scope[:path]
              end
            end
          end

          def action_path(name, path_names = nil)
            path_names ||= @scope[:path_names]
            path_names[name.to_sym] || name.to_s
          end

          def options_for_action(action, options)
            options.reverse_merge(
              :to => action,
              :as => name_for_action(action)
            )
          end

          def name_for_action(action)
            name_prefix = @scope[:name_prefix].blank? ? "" : "#{@scope[:name_prefix]}_"
            shallow_prefix = @scope[:shallow_prefix].blank? ? "" : "#{@scope[:shallow_prefix]}_"

            case action
            when :index, :create
              "#{name_prefix}#{parent_resource.collection_name}"
            when :show, :update, :destroy
              if parent_resource.shallow?
                "#{shallow_prefix}#{parent_resource.member_name}"
              else
                "#{name_prefix}#{parent_resource.member_name}"
              end
            when :edit
              if parent_resource.shallow?
                "edit_#{shallow_prefix}#{parent_resource.member_name}"
              else
                "edit_#{name_prefix}#{parent_resource.member_name}"
              end
            when :new
              "new_#{name_prefix}#{parent_resource.member_name}"
            else
              case @scope[:scope_level]
              when :collection
                "#{action}_#{name_prefix}#{parent_resource.collection_name}"
              when :new
                "#{action}_new_#{name_prefix}#{parent_resource.member_name}"
              else
                if parent_resource.shallow?
                  "#{action}_#{shallow_prefix}#{parent_resource.member_name}"
                else
                  "#{action}_#{name_prefix}#{parent_resource.member_name}"
                end
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
