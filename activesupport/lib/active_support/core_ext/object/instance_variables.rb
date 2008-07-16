class Object
  # Available in 1.8.6 and later.
  unless respond_to?(:instance_variable_defined?)
    def instance_variable_defined?(variable)
      instance_variables.include?(variable.to_s)
    end
  end

  # Returns a hash that maps instance variable names without "@" to their
  # corresponding values. Keys are strings both in Ruby 1.8 and 1.9.
  #
  #   class C
  #     def initialize(x, y)
  #       @x, @y = x, y
  #     end
  #   end
  #   
  #   C.new(0, 1).instance_values # => {"x" => 0, "y" => 1}
  def instance_values #:nodoc:
    instance_variables.inject({}) do |values, name|
      values[name.to_s[1..-1]] = instance_variable_get(name)
      values
    end
  end

  # Returns an array of instance variable names including "@". They are strings
  # both in Ruby 1.8 and 1.9.
  #
  #   class C
  #     def initialize(x, y)
  #       @x, @y = x, y
  #     end
  #   end
  #   
  #   C.new(0, 1).instance_variable_names # => ["@y", "@x"]
  if RUBY_VERSION >= '1.9'
    def instance_variable_names
      instance_variables.map { |var| var.to_s }
    end
  else
    alias_method :instance_variable_names, :instance_variables
  end

  # Copies the instance variables of +object+ into +self+.
  #
  # Instance variable names in the +exclude+ array are ignored. If +object+
  # responds to <tt>protected_instance_variables</tt> the ones returned are
  # also ignored. For example, Rails controllers implement that method.
  #
  # In both cases strings and symbols are understood, and they have to include
  # the at sign.
  #
  #   class C
  #     def initialize(x, y, z)
  #       @x, @y, @z = x, y, z
  #     end
  #   
  #     def protected_instance_variables
  #       %w(@z)
  #     end
  #   end
  #   
  #   a = C.new(0, 1, 2)
  #   b = C.new(3, 4, 5)
  #   
  #   a.copy_instance_variables_from(b, [:@y])
  #   # a is now: @x = 3, @y = 1, @z = 2
  def copy_instance_variables_from(object, exclude = []) #:nodoc:
    exclude += object.protected_instance_variables if object.respond_to? :protected_instance_variables

    vars = object.instance_variables.map(&:to_s) - exclude.map(&:to_s)
    vars.each { |name| instance_variable_set(name, object.instance_variable_get(name)) }
  end
end
