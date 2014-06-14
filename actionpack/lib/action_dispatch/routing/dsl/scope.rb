module ActionDispatch
  module Routing
    class Mapper
      class Scope
        URL_OPTIONS = [:protocol, :subdomain, :domain, :host, :port]
        SCOPE_OPTIONS = [:path, :shallow_path, :as, :shallow_prefix, :module,
                         :controller, :action, :path_names, :constraints,
                         :shallow, :blocks, :defaults, :options]

        attr_reader :parent, :routes, *SCOPE_OPTIONS

        SCOPE_OPTIONS.each do |option|
          define_method("#{option}=") do |new_option|
            instance_variable_set("@#{option}", new_option)
            send("merge_#{option}_scope")
          end
        end

        def initialize(*args)
          options = args.extract_options!.dup

          options[:path] = args.flatten.join('/') if args.any?
          options[:constraints] ||= {}

          unless nested_scope?
            options[:shallow_path] ||= options[:path] if options.key?(:path)
            options[:shallow_prefix] ||= options[:as] if options.key?(:as)
          end

          if options[:constraints].is_a?(Hash)
            defaults = options[:constraints].select do
              |k, v| URL_OPTIONS.include?(k) && (v.is_a?(String) || v.is_a?(Fixnum))
            end

            (options[:defaults] ||= {}).reverse_merge!(defaults)
          else
            block, options[:constraints] = options[:constraints], {}
          end

          SCOPE_OPTIONS.each do |option|
            if option == :blocks
              value = block
            elsif option == :options
              value = options
            else
              value = options.delete(option)
            end

            instance_variable_set("@#{option}", value) if value
          end
        end

        # We set a new parent and therefore recalculate all options
        def parent=(new_parent)
          @parent = new_parent
          return unless @parent
          SCOPE_OPTIONS.except(:controller, :action).each do |option|
            send("merge_#{option}_scope")
          end
        end

        private
          def merge_path_scope #:nodoc:
            @path = Mapper.normalize_path("#{parent.path}/#{@path}")
          end

          def merge_shallow_path_scope #:nodoc:
            @shallow_path = Mapper.normalize_path("#{parent.shallow_path}/#{@shallow_path}")
          end

          def merge_as_scope #:nodoc:
            @as = "#{parent.as}_#{@as}" if parent.as
          end

          def merge_shallow_prefix_scope #:nodoc:
            if parent.shallow_prefix
              @shallow_prefix = "#{parent.shallow_prefix}_#{@shallow_prefix}"
            end
          end

          def merge_module_scope #:nodoc:
            @module = "#{parent}/#{child}" if parent.module
          end

          def merge_path_names_scope #:nodoc:
            @path_names = merge_options_scope(parent.path_names, @path_names)
          end

          def merge_constraints_scope #:nodoc:
            @constraints = merge_options_scope(parent.constraints, @constraints)
          end

          def merge_defaults_scope #:nodoc:
            @defaults = merge_options_scope(parent.defaults, @defaults)
          end

          def merge_blocks_scope #:nodoc:
            merged = parent.blocks ? parent.blocks.dup : []
            merged << @blocks if @blocks
            @blocks = merged
          end

          def merge_options_scope(parent, child) #:nodoc:
            (parent || {}).except(*override_keys(child)).merge(child)
          end

          def merge_shallow_scope #:nodoc:
            @shallow = !!@shallow
          end

          def override_keys(child) #:nodoc:
            child.key?(:only) || child.key?(:except) ? [:only, :except] : []
          end
      end
    end
  end
end
