class Array
  # Returns a random element from the array.
  def random_element
    self[Kernel.rand(length)]
  end
end