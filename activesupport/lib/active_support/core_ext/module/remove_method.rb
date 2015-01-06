class Module
  # Remove the named method, if it exists.
  def remove_possible_method(method)
    if method_defined?(method) || private_method_defined?(method)
      undef_method(method)
    end
  end

  # Replace the existing method definition, if there is one, with the contents
  # of the block.
  def redefine_method(method, &block)
    remove_possible_method(method)
    define_method(method, &block)
  end
end
