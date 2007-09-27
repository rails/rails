class Object
  # Available in 1.8.6 and later.
  unless respond_to?(:instance_variable_defined?)
    def instance_variable_defined?(variable)
      instance_variables.include?(variable.to_s)
    end
  end
end
