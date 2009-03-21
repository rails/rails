class Array
  # Returns a random element from the array.
  def rand
    self[Kernel.rand(length)]
  end
end
