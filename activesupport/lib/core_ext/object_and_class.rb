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
end

class Class #:nodoc:
  def remove_subclasses
    Object.remove_subclasses_of(self)
  end

  def subclasses
    Object.subclasses_of(self)
  end
end
