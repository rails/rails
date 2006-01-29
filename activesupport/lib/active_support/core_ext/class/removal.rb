class Class #:nodoc:
  def remove_subclasses
    Object.remove_subclasses_of(self)
  end

  def subclasses
    Object.subclasses_of(self).map { |o| o.to_s }
  end

  def remove_class(klass)
    if klass.to_s.include? "::"
      modules     = klass.to_s.split("::")
      final_klass = modules.pop
              
      final_module = modules.inject(Object) { |final_type, part| final_type.const_get(part) }
      final_module.send(:remove_const, final_klass) rescue nil
    else
      Object.send(:remove_const, klass.to_s) rescue nil
    end
  end
end