require 'action_dispatch/routing/dsl/abstract_scope/normalization'
require 'action_dispatch/routing/dsl/abstract_scope/mount'
require 'action_dispatch/routing/dsl/abstract_scope/match'
require 'action_dispatch/routing/dsl/abstract_scope/http_helpers'

module ActionDispatch
  module Routing
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
        attr_accessor :set
        attr_reader :controller, :action

        def initialize(parent, *args)
          if parent
            @parent, @set, @concerns = parent, parent.set, parent.concerns
          else
            @parent, @concerns = nil, {}
          end

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
            instance_variable_set(:"@#{option}", value) if value
          end
        end

        def path
          parent_path = parent ? parent.path : nil
          merge_with_slash(parent_path, @path)
        end

        def shallow_path
          parent_shallow_path = parent ? parent.shallow_path : nil
          merge_with_slash(parent_shallow_path, @shallow_path)
        end

        def as
          parent_as = parent ? parent.as : nil
          merge_with_underscore(parent_as, @as)
        end

        def shallow_prefix
          parent_shallow_prefix = parent ? parent.shallow_prefix : nil
          merge_with_underscore(parent_shallow_prefix, @shallow_prefix)
        end

        def module
          parent ? "#{parent.module}/#{@module}" : @module
        end

        def path_names
          parent_path_names = parent ? parent.path_names : nil
          merge_hashes(parent_path_names, @path_names)
        end

        def constraints
          parent_constraints = parent ? parent.constraints : nil
          merge_hashes(parent_constraints, @constraints)
        end

        def shallow?
          @shallow
        end

        def blocks
          parent_blocks = parent ? parent.blocks : nil
          merged = parent_blocks ? parent_blocks.dup : []
          merged << @blocks if @blocks
          merged
        end

        def defaults
          parent_defaults = parent ? parent.defaults : nil
          merge_hashes(parent_defaults, @defaults)
        end

        def options
          parent_options = parent ? parent.options : nil
          merge_hashes(parent_options, @options)
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
  end
end
