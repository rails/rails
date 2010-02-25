class Object
  # Returns the object's singleton class.
  def singleton_class
    class << self
      self
    end
  end unless respond_to?(:singleton_class)

  # class_eval on an object acts like singleton_class_eval.
  def class_eval(*args, &block)
    singleton_class.class_eval(*args, &block)
  end
end
