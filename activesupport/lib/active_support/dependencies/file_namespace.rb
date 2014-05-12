class FileNamespace
  attr_reader :path, :const_scope, :const_name

  def initialize(options = {})
    @path = options[:path]
    @const_scope = options[:const_scope] || @path.safe_constantize
    infer_nesting(options[:const_name] || @path.camelize)
  end

  def hash
    path.hash
  end

  def ==(other)
    path == other.path
  end

  def embrace(const)
    const_name = [@const_name, const].join('::')
    new path: const_name.underscore, const_name: const_name
  end

  def define_constants!
    old_constants = constants

    yield

    constants - old_constants
  end

  def unload!
    parent.remove_const(@const_scope) if reachable?
  end

  private
    def reachable?
      const_defined? && @const_scope.reachable?
    end

    def constants
      @const_scope.local_constants
    end

    def const_defined?
      defined?(@const_scope)
    end

    def parent
      @parent || Object
    end

    def infer_nesting(nestable)
      @parent, @const_name = nestable.split('::', 2)
    end
end
