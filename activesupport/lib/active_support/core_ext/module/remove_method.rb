class Module
  def remove_possible_method(method)
    if method_defined?(method) || private_method_defined?(method)
      remove_method(method)
    end
  rescue NameError
    # If the requested method is defined on a superclass or included module,
    # method_defined? returns true but remove_method throws a NameError.
    # Ignore this.
  end

  def redefine_method(method, &block)
    remove_possible_method(method)
    define_method(method, &block)
  end
end
