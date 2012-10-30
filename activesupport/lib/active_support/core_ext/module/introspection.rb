require 'active_support/inflector'

class Module
  # Returns the name of the module containing this one.
  #
  #   M::N.parent_name # => "M"
  def parent_name
    if defined? @parent_name
      @parent_name
    else
      @parent_name = name =~ /::[^:]+\Z/ ? $`.freeze : nil
    end
  end

  # Returns the module which contains this one according to its name.
  #
  #   module M
  #     module N
  #     end
  #   end
  #   X = M::N
  #
  #   M::N.parent # => M
  #   X.parent    # => M
  #
  # The parent of top-level and anonymous modules is Object.
  #
  #   M.parent          # => Object
  #   Module.new.parent # => Object
  def parent
    parent_name ? ActiveSupport::Inflector.constantize(parent_name) : Object
  end

  # Returns all the parents of this module according to its name, ordered from
  # nested outwards. The receiver is not contained within the result.
  #
  #   module M
  #     module N
  #     end
  #   end
  #   X = M::N
  #
  #   M.parents    # => [Object]
  #   M::N.parents # => [M, Object]
  #   X.parents    # => [M, Object]
  def parents
    parents = []
    if parent_name
      parts = parent_name.split('::')
      until parts.empty?
        parents << ActiveSupport::Inflector.constantize(parts * '::')
        parts.pop
      end
    end
    parents << Object unless parents.include? Object
    parents
  end

  def local_constants #:nodoc:
    constants(false)
  end

  # *DEPRECATED*: Use +local_constants+ instead.
  #
  # Returns the names of the constants defined locally as strings.
  #
  #   module M
  #     X = 1
  #   end
  #   M.local_constant_names # => ["X"]
  #
  # This method is useful for forward compatibility, since Ruby 1.8 returns
  # constant names as strings, whereas 1.9 returns them as symbols.
  def local_constant_names
    ActiveSupport::Deprecation.warn 'Module#local_constant_names is deprecated, use Module#local_constants instead'
    local_constants.map { |c| c.to_s }
  end
end
