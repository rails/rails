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
    attr_reader :controller, :action

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
        Mapper.normalize_path("#{parent}/#{child}")
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
