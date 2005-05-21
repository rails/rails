class Object #:nodoc:
  def remove_subclasses_of(superclass)
    subclasses_of(superclass).each { |subclass| Object.send(:remove_const, subclass) rescue nil }
  end

  def subclasses_of(superclass)
    subclasses = []
    ObjectSpace.each_object(Class) do |k|
      next if !k.ancestors.include?(superclass) || superclass == k || k.to_s.include?("::") || subclasses.include?(k.to_s)
      subclasses << k.to_s
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
    Object.subclasses_of(self)
  end
end
