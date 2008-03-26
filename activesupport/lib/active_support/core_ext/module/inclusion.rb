class Module
  # Returns the classes in the current ObjectSpace where this module has been
  # mixed in according to Module#included_modules.
  #
  #   module M
  #   end
  #   
  #   module N
  #     include M
  #   end
  #   
  #   class C
  #     include M
  #   end
  #   
  #   class D < C
  #   end
  #
  #   p M.included_in_classes # => [C, D]
  #
  def included_in_classes
    classes = []
    ObjectSpace.each_object(Class) { |k| classes << k if k.included_modules.include?(self) }

    classes.reverse.inject([]) do |unique_classes, klass| 
      unique_classes << klass unless unique_classes.collect { |k| k.to_s }.include?(klass.to_s)
      unique_classes
    end
  end
end