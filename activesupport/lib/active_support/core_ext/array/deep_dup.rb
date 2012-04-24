class Array
  # Returns a deep copy of array.
  def deep_dup
    map { |it| it.deep_dup }
  end
end
