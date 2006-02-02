class Class #:nodoc:
  def remove_subclasses
    Object.remove_subclasses_of(self)
  end

  def subclasses
    Object.subclasses_of(self).map { |o| o.to_s }
  end

  def remove_class(*klasses)
    klasses.each do |klass|
      basename = klass.to_s.split("::").last
      parent = klass.parent
      parent.send :remove_const, basename unless parent == klass
    end
  end
end