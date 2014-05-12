class FileNamespace
  attr_reader :file_path, :const_scope, :const_name

  def initialize(file_path)
    @file_path = file_path
    @const_scope = file_path.safe_constantize
    @parent, @const_name = split_hierarchy(file_path.camelize)
  end

  def hash
    file_path.hash
  end

  def ==(other)
    file_path == other.file_path
  end

  def reachable?
    const_defined? && @const_scope.reachable?
  end

  def embrace(const)
    new [@const_name, const].join('::').underscore
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

    def constants
      @const_scope.local_constants
    end

    def const_defined?
      defined?(@const_scope)
    end

    def parent
      @parent || Object
    end

    def split_hierarchy(camel_string)
      camel_string.split('::', 2)
    end
end
