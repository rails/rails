module ActionDispatch
  module Routing
    class ResourceScope < Scope #:nodoc:
      VALID_ON_OPTIONS  = [:new, :collection, :member]
      RESOURCE_OPTIONS  = [:as, :controller, :path, :only, :except, :param, :concerns]
      CANONICAL_ACTIONS = %w(index create new show update destroy)

      attr_reader :param

      def initialize(entity, options = {})
        @name       = entity.to_s
        @path       = (options[:path] || @name).to_s
        @controller = (options[:controller] || @name).to_s
        @as         = options[:as]
        @param      = (options[:param] || :id).to_sym
        @options    = options
        @shallow    = false
      end

      def default_actions
        [:index, :create, :new, :show, :update, :destroy, :edit]
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
        @plural ||= name.to_s
      end

      def singular
        @singular ||= name.to_s.singularize
      end

      alias :member_name :singular

      def collection_name
        singular == plural ? "#{plural}_index" : plural
      end

      alias :collection_scope :path

      def member_scope
        "#{path}/:#{param}"
      end

      alias :shallow_scope :member_scope

      def new_scope(new_path)
        "#{path}/#{new_path}"
      end

      def nested_param
        :"#{singular}_#{param}"
      end

      def nested_scope
        "#{path}/:#{nested_param}"
      end

      def shallow?
        @shallow
      end

      def resources_path_names(options)
        @path_names.merge!(options)
      end

      def collection(&block)
        new_collection = CollectionScope.new(collection_scope)
        new_collection.parent = self
        new_collection.instance_exec(&block)
        @routes += new_collection.routes
      end

      def member(&block)
        new_member = MemberScope.new(member_scope)
        new_member.parent = self
        if shallow?
          new_member.as = @shallow_prefix
          new_member.path = @shallow_path
        end
        new_member.instance_exec(&block)
        @routes += new_member.routes
      end

      def new(&block)
        new_new = NewScope.new(new_scope(action_path(:new)))
        new_new.parent = self
        new_new.instance_exec(&block)
        @routes += new_new.routes
      end

      def nested(&block)
        new_nested = NestedScope.new(nested_scope, nested_options)
        new_nested.parent = self
        if shallow? && shallow_nesting_depth > 1
          new_nested.as = @shallow_prefix
          new_nested.path = @shallow_path
        end
        new_nested.instance_exec(&block)
        @routes += new_nested.routes
      end

      # See ActionDispatch::Routing::Mapper::Scoping#namespace
      def namespace(path, options = {})
        nested { super }
      end

      def shallow
        scope(:shallow => true) do
          yield
        end
      end

      def shallow?
        !!@shallow
      end

      def root(path, options={})
        if path.is_a?(String)
          options[:to] = path
        elsif path.is_a?(Hash) and options.empty?
          options = path
        else
          raise ArgumentError, "must be called with a path and/or options"
        end

        if @scope[:scope_level] == :resources
          with_scope_level(:root) do
            scope(parent_resource.path) do
              super(options)
            end
          end
        else
          super(options)
        end
      end

      def build(&block)
        yield if block_given?

        concerns(options[:concerns]) if options[:concerns]

        collection do
          get  :index if actions.include?(:index)
          post :create if actions.include?(:create)
        end

        new do
          get :new
        end if actions.include?(:new)

        set_member_mappings_for_resource
      end


      protected

        def action_options?(options) #:nodoc:
          options[:only] || options[:except]
        end

        def scope_action_options? #:nodoc:
          @options && (@options[:only] || @options[:except])
        end

        def scope_action_options #:nodoc:
          @options.slice(:only, :except)
        end

        def with_exclusive_scope(&block)
          new_exclusive = ExclusiveScope.new(as: nil, path: nil)
          new_exclusive.parent = self
          new_exclusive.instance_exec(&block)
          @routes += new_exclusive.routes
        end

        def nested_options #:nodoc:
          options = { :as => member_name }
          options[:constraints] = {
            nested_param => param_constraint
          } if param_constraint?

          options
        end

        def nesting_depth #:nodoc:
          @nesting.size
        end

        def shallow_nesting_depth #:nodoc:
          @nesting.select(&:shallow?).size
        end

        def param_constraint? #:nodoc:
          @constraints && @constraints[param].is_a?(Regexp)
        end

        def param_constraint #:nodoc:
          @constraints[param]
        end

        def canonical_action?(action, flag) #:nodoc:
          flag && resource_method_scope? && CANONICAL_ACTIONS.include?(action.to_s)
        end

        def path_for_action(action, path) #:nodoc:
          if canonical_action?(action, path.blank?)
            @scope[:path].to_s
          else
            "#{@scope[:path]}/#{action_path(action, path)}"
          end
        end

        def action_path(name, path = nil) #:nodoc:
          name = name.to_sym if name.is_a?(String)
          path || @path_names[name] || name.to_s
        end

        def prefix_name_for_action(as, action) #:nodoc:
          if as
            prefix = as
          elsif !canonical_action?(action, @scope_level)
            prefix = action
          end
          prefix.to_s.tr('-', '_') if prefix
        end

        def name_for_action(as, action) #:nodoc:
          prefix = prefix_name_for_action(as, action)
          prefix = Mapper.normalize_name(prefix) if prefix
          name_prefix = @scope[:as]

          if parent_resource
            return nil unless as || action

            collection_name = parent_resource.collection_name
            member_name = parent_resource.member_name
          end

          name = case @scope[:scope_level]
          when :nested
            [name_prefix, prefix]
          when :collection
            [prefix, name_prefix, collection_name]
          when :new
            [prefix, :new, name_prefix, member_name]
          when :member
            [prefix, name_prefix, member_name]
          when :root
            [name_prefix, collection_name, prefix]
          else
            [name_prefix, member_name, prefix]
          end

          if candidate = name.select(&:present?).join("_").presence
            # If a name was not explicitly given, we check if it is valid
            # and return nil in case it isn't. Otherwise, we pass the invalid name
            # forward so the underlying router engine treats it and raises an exception.
            if as.nil?
              candidate unless @set.routes.find { |r| r.name == candidate } || candidate !~ /\A[_a-z]/i
            else
              candidate
            end
          end
        end

        def set_member_mappings_for_resource
          member do
            get :edit if actions.include?(:edit)
            get :show if actions.include?(:show)
            if actions.include?(:update)
              patch :update
              put   :update
            end
            delete :destroy if actions.include?(:destroy)
          end
        end
    end

    class SingletonResource < ResourceScope #:nodoc:
      def initialize(entity, options)
        super
        @as         = nil
        @controller = (options[:controller] || plural).to_s
        @as         = options[:as]
      end

      def default_actions
        [:show, :create, :update, :destroy, :new, :edit]
      end

      def plural
        @plural ||= name.to_s.pluralize
      end

      def singular
        @singular ||= name.to_s
      end

      def build
        yield if block_given?

        concerns(options[:concerns]) if options[:concerns]

        collection do
          post :create
        end if actions.include?(:create)

        new do
          get :new
        end if actions.include?(:new)

        set_member_mappings_for_resource
      end

      alias :member_name :singular
      alias :collection_name :singular

      alias :member_scope :path
      alias :nested_scope :path
    end

    def resource(*resources, &block)
      options = resources.extract_options!.dup

      if apply_common_behavior_for(:resource, resources, options, &block)
        return self
      end
      resource_scope(SingletonResource, resources.pop, &block)
    end

    def resources(*resources, &block)
      options = resources.extract_options!.dup

      if apply_common_behavior_for(:resources, resources, options, &block)
        return self
      end
      resource_scope(ResourceScope, resources.pop, &block)
    end

    private
      def resource_scope(klass, resources, &block)
        options = resources.extract_options!.dup
        resources.each do |resource|
          new_resource = klass.new(resource, options)
          new_resource.shallow = @shallow
          @nesting.push new_resource
          new_resource.parent = self
          new_resource.build(&block)
          new_resource.instance_exec(&block) if block_given?
          @nesting.pop
          @routes += new_resource.routes
        end
      end

      def apply_common_behavior_for(method, resources, options, &block) #:nodoc:
        if resources.length > 1
          resources.each { |r| send(method, r, options, &block) }
          return true
        end

        if options.delete(:shallow)
          shallow do
            send(method, resources.pop, options, &block)
          end
          return true
        end

        if resource_scope?
          nested { send(method, resources.pop, options, &block) }
          return true
        end

        options.keys.each do |k|
          (options[:constraints] ||= {})[k] = options.delete(k) if options[k].is_a?(Regexp)
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

        false
      end
  end
end
