class Object #:nodoc:
  def remove_subclasses_of(*superclasses)
    subclasses_of(*superclasses).each do |subclass|
      subclass.instance_variables.each { |v| subclass.send(:remove_instance_variable, v) }
      Object.send(:remove_const, subclass.to_s) rescue nil
    end
  end
  
  def remove_instance_variables_of(klass)
    ObjectSpace.each_object(Class) do |k|
      if k.to_s == klass
        k.instance_variables.each { |v| k.send(:remove_instance_variable, v) }
      end  
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

  # "", "   ", nil, and 0 are all blank
  def blank?
    if respond_to?(:empty?) && respond_to?(:strip)
      strip.empty?
    elsif respond_to? :empty?
      empty?
    elsif respond_to? :zero?
      zero?
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
