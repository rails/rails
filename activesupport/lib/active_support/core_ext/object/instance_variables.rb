# frozen_string_literal: true

class Object
  # Returns a hash with string keys that maps instance variable names without "@" to their
  # corresponding values.
  #
  #   class C
  #     def initialize(x, y)
  #       @x, @y = x, y
  #     end
  #   end
  #
  #   C.new(0, 1).instance_values # => {"x" => 0, "y" => 1}
  def instance_values
    instance_variables.to_h do |ivar|
      [ivar[1..-1].freeze, instance_variable_get(ivar)]
    end
  end

  # Returns an array of instance variable names as strings including "@".
  #
  #   class C
  #     def initialize(x, y)
  #       @x, @y = x, y
  #     end
  #   end
  #
  #   C.new(0, 1).instance_variable_names # => ["@y", "@x"]
  def instance_variable_names
    instance_variables.map(&:name)
  end
end
