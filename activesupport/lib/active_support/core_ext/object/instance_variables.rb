class Object
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
    Hash[instance_variables.map { |name| [name.to_s[1..-1], instance_variable_get(name)] }]
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
end
