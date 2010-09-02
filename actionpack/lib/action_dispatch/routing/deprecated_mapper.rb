require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/with_options'
require 'active_support/core_ext/object/try'

module ActionDispatch
  module Routing
    class RouteSet
      attr_accessor :controller_namespaces

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
        ActionController::Base.descendants.each do |klass|
          next if klass.anonymous?
          namespaces << klass.name.underscore.split('/')[0...-1].join('/')
        end
        namespaces.delete('')
        namespaces
      end
    end

    class DeprecatedMapper #:nodoc:
      def initialize(set) #:nodoc:
        ActiveSupport::Deprecation.warn "You are using the old router DSL which will be removed in Rails 3.1. " <<
          "Please check how to update your routes file at: http://www.engineyard.com/blog/2010/the-lowdown-on-routes-in-rails-3/"
        @set = set
      end

      def connect(path, options = {})
        options = options.dup

        if conditions = options.delete(:conditions)
          conditions = conditions.dup
          method = [conditions.delete(:method)].flatten.compact
          method.map! { |m|
            m = m.to_s.upcase

            if m == "HEAD"
              raise ArgumentError, "HTTP method HEAD is invalid in route conditions. Rails processes HEAD requests the same as GETs, returning just the response headers"
            end

            unless HTTP_METHODS.include?(m.downcase.to_sym)
              raise ArgumentError, "Invalid HTTP method specified in route conditions"
            end

            m
          }

          if method.length > 1
            method = Regexp.union(*method)
          elsif method.length == 1
            method = method.first
          else
            method = nil
          end
        end

        path_prefix = options.delete(:path_prefix)
        name_prefix = options.delete(:name_prefix)
        namespace  = options.delete(:namespace)

        name = options.delete(:_name)
        name = "#{name_prefix}#{name}" if name_prefix

        requirements = options.delete(:requirements) || {}
        defaults = options.delete(:defaults) || {}
        options.each do |k, v|
          if v.is_a?(Regexp)
            if value = options.delete(k)
              requirements[k.to_sym] = value
            end
          else
            value = options.delete(k)
            defaults[k.to_sym] = value.is_a?(Symbol) ? value : value.to_param
          end
        end

        requirements.each do |_, requirement|
          if requirement.source =~ %r{\A(\\A|\^)|(\\Z|\\z|\$)\Z}
            raise ArgumentError, "Regexp anchor characters are not allowed in routing requirements: #{requirement.inspect}"
          end
          if requirement.multiline?
            raise ArgumentError, "Regexp multiline option not allowed in routing requirements: #{requirement.inspect}"
          end
        end

        requirements[:controller] ||= @set.controller_constraints

        if defaults[:controller]
          defaults[:action] ||= 'index'
          defaults[:controller] = defaults[:controller].to_s
          defaults[:controller] = "#{namespace}#{defaults[:controller]}" if namespace
        end

        if defaults[:action]
          defaults[:action] = defaults[:action].to_s
        end

        if path.is_a?(String)
          path = "#{path_prefix}/#{path}" if path_prefix
          path = path.gsub('.:format', '(.:format)')
          path = optionalize_trailing_dynamic_segments(path, requirements, defaults)
          glob = $1.to_sym if path =~ /\/\*(\w+)$/
          path = ::Rack::Mount::Utils.normalize_path(path)

          if glob && !defaults[glob].blank?
            raise ActionController::RoutingError, "paths cannot have non-empty default values"
          end
        end

        app = Routing::RouteSet::Dispatcher.new(:defaults => defaults, :glob => glob)

        conditions = {}
        conditions[:request_method] = method if method
        conditions[:path_info] = path if path

        @set.add_route(app, conditions, requirements, defaults, name)
      end

      def optionalize_trailing_dynamic_segments(path, requirements, defaults) #:nodoc:
        path = (path =~ /^\//) ? path.dup : "/#{path}"
        optional, segments = true, []

        required_segments = requirements.keys
        required_segments -= defaults.keys.compact

        old_segments = path.split('/')
        old_segments.shift
        length = old_segments.length

        old_segments.reverse.each_with_index do |segment, index|
          required_segments.each do |required|
            if segment =~ /#{required}/
              optional = false
              break
            end
          end

          if optional
            if segment == ":id" && segments.include?(":action")
              optional = false
            elsif segment == ":controller" || segment == ":action" || segment == ":id"
              # Ignore
            elsif !(segment =~ /^:\w+$/) &&
                !(segment =~ /^:\w+\(\.:format\)$/)
              optional = false
            elsif segment =~ /^:(\w+)$/
              if defaults.has_key?($1.to_sym)
                defaults.delete($1.to_sym) if defaults[$1.to_sym].nil?
              else
                optional = false
              end
            end
          end

          if optional && index < length - 1
            segments.unshift('(/', segment)
            segments.push(')')
          elsif optional
            segments.unshift('/(', segment)
            segments.push(')')
          else
            segments.unshift('/', segment)
          end
        end

        segments.join
      end
      private :optionalize_trailing_dynamic_segments

      # Creates a named route called "root" for matching the root level request.
      def root(options = {})
        if options.is_a?(Symbol)
          if source_route = @set.named_routes.routes[options]
            options = source_route.defaults.merge({ :conditions => source_route.conditions })
          end
        end
        named_route("root", '', options)
      end

      def named_route(name, path, options = {}) #:nodoc:
        options[:_name] = name
        connect(path, options)
      end

      def namespace(name, options = {}, &block)
        if options[:namespace]
          with_options({:path_prefix => "#{options.delete(:path_prefix)}/#{name}", :name_prefix => "#{options.delete(:name_prefix)}#{name}_", :namespace => "#{options.delete(:namespace)}#{name}/" }.merge(options), &block)
        else
          with_options({:path_prefix => name, :name_prefix => "#{name}_", :namespace => "#{name}/" }.merge(options), &block)
        end
      end

      def method_missing(route_name, *args, &proc) #:nodoc:
        super unless args.length >= 1 && proc.nil?
        named_route(route_name, *args)
      end

      INHERITABLE_OPTIONS = :namespace, :shallow

      class Resource #:nodoc:
        DEFAULT_ACTIONS = :index, :create, :new, :edit, :show, :update, :destroy

        attr_reader :collection_methods, :member_methods, :new_methods
        attr_reader :path_prefix, :name_prefix, :path_segment
        attr_reader :plural, :singular
        attr_reader :options, :defaults

        def initialize(entities, options, defaults)
          @plural   ||= entities
          @singular ||= options[:singular] || plural.to_s.singularize
          @path_segment = options.delete(:as) || @plural

          @options = options
          @defaults = defaults

          arrange_actions
          add_default_actions
          set_allowed_actions
          set_prefixes
        end

        def controller
          @controller ||= "#{options[:namespace]}#{(options[:controller] || plural).to_s}"
        end

        def requirements(with_id = false)
          @requirements   ||= @options[:requirements] || {}
          @id_requirement ||= { :id => @requirements.delete(:id) || /[^#{Routing::SEPARATORS.join}]+/ }

          with_id ? @requirements.merge(@id_requirement) : @requirements
        end

        def conditions
          @conditions ||= @options[:conditions] || {}
        end

        def path
          @path ||= "#{path_prefix}/#{path_segment}"
        end

        def new_path
          new_action   = self.options[:path_names][:new] if self.options[:path_names]
          new_action ||= self.defaults[:path_names][:new]
          @new_path  ||= "#{path}/#{new_action}"
        end

        def shallow_path_prefix
          @shallow_path_prefix ||= @options[:shallow] ? @options[:namespace].try(:sub, /\/$/, '') : path_prefix
        end

        def member_path
          @member_path ||= "#{shallow_path_prefix}/#{path_segment}/:id"
        end

        def nesting_path_prefix
          @nesting_path_prefix ||= "#{shallow_path_prefix}/#{path_segment}/:#{singular}_id"
        end

        def shallow_name_prefix
          @shallow_name_prefix ||= @options[:shallow] ? @options[:namespace].try(:gsub, /\//, '_') : name_prefix
        end

        def nesting_name_prefix
          "#{shallow_name_prefix}#{singular}_"
        end

        def action_separator
          @action_separator ||= ActionController::Base.resource_action_separator
        end

        def uncountable?
          @singular.to_s == @plural.to_s
        end

        def has_action?(action)
          !DEFAULT_ACTIONS.include?(action) || action_allowed?(action)
        end

        protected
          def arrange_actions
            @collection_methods = arrange_actions_by_methods(options.delete(:collection))
            @member_methods     = arrange_actions_by_methods(options.delete(:member))
            @new_methods        = arrange_actions_by_methods(options.delete(:new))
          end

          def add_default_actions
            add_default_action(member_methods, :get, :edit)
            add_default_action(new_methods, :get, :new)
          end

          def set_allowed_actions
            only, except = @options.values_at(:only, :except)
            @allowed_actions ||= {}

            if only == :all || except == :none
              only = nil
              except = []
            elsif only == :none || except == :all
              only = []
              except = nil
            end

            if only
              @allowed_actions[:only] = Array(only).map {|a| a.to_sym }
            elsif except
              @allowed_actions[:except] = Array(except).map {|a| a.to_sym }
            end
          end

          def action_allowed?(action)
            only, except = @allowed_actions.values_at(:only, :except)
            (!only || only.include?(action)) && (!except || !except.include?(action))
          end

          def set_prefixes
            @path_prefix = options.delete(:path_prefix)
            @name_prefix = options.delete(:name_prefix)
          end

          def arrange_actions_by_methods(actions)
            (actions || {}).inject({}) do |flipped_hash, (key, value)|
              (flipped_hash[value] ||= []) << key
              flipped_hash
            end
          end

          def add_default_action(collection, method, action)
            (collection[method] ||= []).unshift(action)
          end
      end

      class SingletonResource < Resource #:nodoc:
        def initialize(entity, options, defaults)
          @singular = @plural = entity
          options[:controller] ||= @singular.to_s.pluralize
          super
        end

        alias_method :shallow_path_prefix, :path_prefix
        alias_method :shallow_name_prefix, :name_prefix
        alias_method :member_path,         :path
        alias_method :nesting_path_prefix, :path
      end

      def resources(*entities, &block)
        options = entities.extract_options!
        entities.each { |entity| map_resource(entity, options.dup, &block) }
      end

      def resource(*entities, &block)
        options = entities.extract_options!
        entities.each { |entity| map_singleton_resource(entity, options.dup, &block) }
      end

      private
        def map_resource(entities, options = {}, &block)
          resource = Resource.new(entities, options, :path_names => @set.resources_path_names)

          with_options :controller => resource.controller do |map|
            map_associations(resource, options)

            if block_given?
              with_options(options.slice(*INHERITABLE_OPTIONS).merge(:path_prefix => resource.nesting_path_prefix, :name_prefix => resource.nesting_name_prefix), &block)
            end

            map_collection_actions(map, resource)
            map_default_collection_actions(map, resource)
            map_new_actions(map, resource)
            map_member_actions(map, resource)
          end
        end

        def map_singleton_resource(entities, options = {}, &block)
          resource = SingletonResource.new(entities, options, :path_names => @set.resources_path_names)

          with_options :controller => resource.controller do |map|
            map_associations(resource, options)

            if block_given?
              with_options(options.slice(*INHERITABLE_OPTIONS).merge(:path_prefix => resource.nesting_path_prefix, :name_prefix => resource.nesting_name_prefix), &block)
            end

            map_collection_actions(map, resource)
            map_new_actions(map, resource)
            map_member_actions(map, resource)
            map_default_singleton_actions(map, resource)
          end
        end

        def map_associations(resource, options)
          map_has_many_associations(resource, options.delete(:has_many), options) if options[:has_many]

          path_prefix = "#{options.delete(:path_prefix)}#{resource.nesting_path_prefix}"
          name_prefix = "#{options.delete(:name_prefix)}#{resource.nesting_name_prefix}"

          Array(options[:has_one]).each do |association|
            resource(association, options.slice(*INHERITABLE_OPTIONS).merge(:path_prefix => path_prefix, :name_prefix => name_prefix))
          end
        end

        def map_has_many_associations(resource, associations, options)
          case associations
          when Hash
            associations.each do |association,has_many|
              map_has_many_associations(resource, association, options.merge(:has_many => has_many))
            end
          when Array
            associations.each do |association|
              map_has_many_associations(resource, association, options)
            end
          when Symbol, String
            resources(associations, options.slice(*INHERITABLE_OPTIONS).merge(:path_prefix => resource.nesting_path_prefix, :name_prefix => resource.nesting_name_prefix, :has_many => options[:has_many]))
          else
          end
        end

        def map_collection_actions(map, resource)
          resource.collection_methods.each do |method, actions|
            actions.each do |action|
              [method].flatten.each do |m|
                action_path = resource.options[:path_names][action] if resource.options[:path_names].is_a?(Hash)
                action_path ||= action

                map_resource_routes(map, resource, action, "#{resource.path}#{resource.action_separator}#{action_path}", "#{action}_#{resource.name_prefix}#{resource.plural}", m)
              end
            end
          end
        end

        def map_default_collection_actions(map, resource)
          index_route_name = "#{resource.name_prefix}#{resource.plural}"

          if resource.uncountable?
            index_route_name << "_index"
          end

          map_resource_routes(map, resource, :index, resource.path, index_route_name)
          map_resource_routes(map, resource, :create, resource.path, index_route_name)
        end

        def map_default_singleton_actions(map, resource)
          map_resource_routes(map, resource, :create, resource.path, "#{resource.shallow_name_prefix}#{resource.singular}")
        end

        def map_new_actions(map, resource)
          resource.new_methods.each do |method, actions|
            actions.each do |action|
              route_path = resource.new_path
              route_name = "new_#{resource.name_prefix}#{resource.singular}"

              unless action == :new
                route_path = "#{route_path}#{resource.action_separator}#{action}"
                route_name = "#{action}_#{route_name}"
              end

              map_resource_routes(map, resource, action, route_path, route_name, method)
            end
          end
        end

        def map_member_actions(map, resource)
          resource.member_methods.each do |method, actions|
            actions.each do |action|
              [method].flatten.each do |m|
                action_path = resource.options[:path_names][action] if resource.options[:path_names].is_a?(Hash)
                action_path ||= @set.resources_path_names[action] || action

                map_resource_routes(map, resource, action, "#{resource.member_path}#{resource.action_separator}#{action_path}", "#{action}_#{resource.shallow_name_prefix}#{resource.singular}", m, { :force_id => true })
              end
            end
          end

          route_path = "#{resource.shallow_name_prefix}#{resource.singular}"
          map_resource_routes(map, resource, :show, resource.member_path, route_path)
          map_resource_routes(map, resource, :update, resource.member_path, route_path)
          map_resource_routes(map, resource, :destroy, resource.member_path, route_path)
        end

        def map_resource_routes(map, resource, action, route_path, route_name = nil, method = nil, resource_options = {} )
          if resource.has_action?(action)
            action_options = action_options_for(action, resource, method, resource_options)
            formatted_route_path = "#{route_path}.:format"

            if route_name && @set.named_routes[route_name.to_sym].nil?
              map.named_route(route_name, formatted_route_path, action_options)
            else
              map.connect(formatted_route_path, action_options)
            end
          end
        end

        def add_conditions_for(conditions, method)
          {:conditions => conditions.dup}.tap do |options|
            options[:conditions][:method] = method unless method == :any
          end
        end

        def action_options_for(action, resource, method = nil, resource_options = {})
          default_options = { :action => action.to_s }
          require_id = !resource.kind_of?(SingletonResource)
          force_id = resource_options[:force_id] && !resource.kind_of?(SingletonResource)

          case default_options[:action]
            when "index", "new"; default_options.merge(add_conditions_for(resource.conditions, method || :get)).merge(resource.requirements)
            when "create";       default_options.merge(add_conditions_for(resource.conditions, method || :post)).merge(resource.requirements)
            when "show", "edit"; default_options.merge(add_conditions_for(resource.conditions, method || :get)).merge(resource.requirements(require_id))
            when "update";       default_options.merge(add_conditions_for(resource.conditions, method || :put)).merge(resource.requirements(require_id))
            when "destroy";      default_options.merge(add_conditions_for(resource.conditions, method || :delete)).merge(resource.requirements(require_id))
            else                 default_options.merge(add_conditions_for(resource.conditions, method)).merge(resource.requirements(force_id))
          end
        end
    end
  end
end
