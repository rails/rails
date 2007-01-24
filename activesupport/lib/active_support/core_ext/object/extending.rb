class Object #:nodoc:
  def remove_subclasses_of(*superclasses)
    Class.remove_class(*subclasses_of(*superclasses))
  end

  def subclasses_of(*superclasses)
    subclasses = []
    ObjectSpace.each_object(Class) do |k|
      next unless # Exclude this class unless
        superclasses.any? { |superclass| k < superclass } &&        # It *is* a subclass of our supers
        eval("defined?(::#{k}) && ::#{k}.object_id == k.object_id") # It *is* defined
          # Note that we check defined? in case we find a removed class that has
          # yet to be garbage collected.
      subclasses << k
    end
    subclasses
  end
  
  def extended_by
    ancestors = class << self; ancestors end
    ancestors.select { |mod| mod.class == Module } - [ Object, Kernel ]
  end
  
  def copy_instance_variables_from(object, exclude = [])
    exclude += object.protected_instance_variables if object.respond_to? :protected_instance_variables
    
    instance_variables = object.instance_variables - exclude.map { |name| name.to_s }
    instance_variables.each { |name| instance_variable_set(name, object.instance_variable_get(name)) }
  end
  
  def extend_with_included_modules_from(object)
    object.extended_by.each { |mod| extend mod }
  end

  def instance_values
    instance_variables.inject({}) do |values, name|
      values[name[1..-1]] = instance_variable_get(name)
      values
    end
  end
  
  unless defined? instance_exec # 1.9
    def instance_exec(*arguments, &block)
      block.bind(self)[*arguments]
    end
  end
end
