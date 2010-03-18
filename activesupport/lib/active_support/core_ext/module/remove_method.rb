class Module
  def remove_possible_method(method)
    remove_method(method)
  rescue NameError
  end
end