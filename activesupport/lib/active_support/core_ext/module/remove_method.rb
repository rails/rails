class Module
  # Removes the named method, if it exists.
  def remove_possible_method(method)
    if method_defined?(method) || private_method_defined?(method)
      undef_method(method)
    end
  end

  # Removes the named singleton method, if it exists.
  def remove_possible_singleton_method(method)
    singleton_class.instance_eval do
      remove_possible_method(method)
    end
  end

  # Replaces the existing method definition, if there is one, with the passed
  # block as its body.
  def redefine_method(method, &block)
    visibility = method_visibility(method)
    remove_possible_method(method)
    define_method(method, &block)
    send(visibility, method)
  end

  def method_visibility(method) # :nodoc:
    case
    when private_method_defined?(method)
      :private
    when protected_method_defined?(method)
      :protected
    else
      :public
    end
  end
end
