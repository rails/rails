class Object #:nodoc:
  def remove_subclasses_of(*superclasses)
    subclasses_of(*superclasses).each do |subclass|
      Object.send(:remove_const, subclass.to_s) rescue nil
    end
  end
  
  def subclasses_of(*superclasses)
    subclasses = []
    ObjectSpace.each_object(Class) do |k|
      next if (k.ancestors & superclasses).empty? || superclasses.include?(k) || k.to_s.include?("::") || subclasses.include?(k)
      subclasses << k
    end
    subclasses
  end
  
  def extended_by
    ancestors = class << self; ancestors end
    ancestors.select { |mod| mod.class == Module } - [ Object, Kernel ]
  end
  
  def copy_instance_variables_from(object, exclude = [])
    exclude += object.protected_instance_variables if
      object.respond_to? :protected_instance_variables
    
    instance_variables = object.instance_variables - exclude.map { |name| name.to_s }
    instance_variables.each do |name|
      instance_variable_set name, object.instance_variable_get(name)
    end
  end
  
  def extend_with_included_modules_from(object)
    object.extended_by.each { |mod| extend mod }
  end
  
  # "", "   ", nil, [], and {} are blank
  def blank?
    if respond_to?(:empty?) && respond_to?(:strip)
      empty? or strip.empty?
    elsif respond_to?(:empty?)
      empty?
    else
      !self
    end
  end

  def suppress(*exception_classes)
    begin yield
    rescue Exception => e
      raise unless exception_classes.any? {|cls| e.kind_of? cls}
    end
  end
end

class Class #:nodoc:
  def remove_subclasses
    Object.remove_subclasses_of(self)
  end

  def subclasses
    Object.subclasses_of(self).map { |o| o.to_s }
  end
end
