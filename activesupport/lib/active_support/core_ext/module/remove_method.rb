class Module
  def remove_possible_method(method)
    remove_method(method)
  rescue NameError
  end
  
  def redefine_method(method, &block)
    remove_possible_method(method)
    define_method(method, &block)
  end
end