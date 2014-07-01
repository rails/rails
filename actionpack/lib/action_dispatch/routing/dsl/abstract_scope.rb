require 'active_support/core_ext/array/extract_options'
require 'action_dispatch/routing/dsl/abstract_scope/nil_refinement'
require 'action_dispatch/routing/dsl/abstract_scope/normalization'

module DSL
  class AbstractScope
    # Constants
    # =========
    URL_OPTIONS = [:protocol, :subdomain, :domain, :host, :port]
    SCOPE_OPTIONS = [:path, :shallow_path, :as, :shallow_prefix, :module,
                     :controller, :action, :path_names, :constraints,
                     :shallow, :blocks, :defaults, :options]

    # Accessors
    # =========
    attr_accessor :parent
    attr_reader :controller, :action, :set, :concerns

    def initialize(parent, *args)
      @parent, @set, @concerns = parent, parent.set, parent.concerns

      # Extract options out of the variable arguments
      options = args.extract_options!.dup

      options[:path] = args.flatten.join('/') if args.any?
      options[:constraints] ||= {}

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

        # Set instance variables
        instance_variable_set(:"@_#{option}", value) if value
      end
    end

    def path
      merge_with_slash(parent.path, @_path)
    end

    def shallow_path
      merge_with_slash(parent.shallow_path, @_shallow_path)
    end

    def as
      merge_with_underscore(parent.as, @_as)
    end

    def shallow_prefix
      merge_with_underscore(parent.shallow_prefix, @_shallow_prefix)
    end

    def module
      parent ? "#{parent.module}/#{@_module}" : @_module
    end

    def path_names
      merge_hashes(parent.path_names, @_path_names)
    end

    def constraints
      merge_hashes(parent.constraints, @_constraints)
    end

    def shallow?
      @_shallow
    end

    def blocks
      merged = parent.blocks ? parent.blocks.dup : []
      merged << @_blocks if @_blocks
      merged
    end

    def defaults
      merge_hashes(parent.defaults, @_defaults)
    end

    def options
      merge_hashes(parent.options, @_options)
    end

    protected
      def merge_with_slash(parent, child)
        normalize_path("#{parent}/#{child}")
      end

      def merge_with_underscore(parent, child)
        parent ? "#{parent}_#{child}" : child
      end

      def merge_hashes(parent, child)
        (parent || {}).except(*override_keys(child)).merge!(child)
      end

      def override_keys(child) #:nodoc:
        child.key?(:only) || child.key?(:except) ? [:only, :except] : []
      end
  end
end
