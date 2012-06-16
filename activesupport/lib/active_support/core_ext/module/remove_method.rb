class Module
  # Removes the method passed as argument if the method is actually defined,
  # if it's not no error is raised, as it would instead happen using
  # +undef_method+.
  def remove_possible_method(method)
    if method_defined?(method) || private_method_defined?(method)
      undef_method(method)
    end
  end

  def redefine_method(method, &block)
    remove_possible_method(method)
    define_method(method, &block)
  end
end
