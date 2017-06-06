class Array
  # Return whether they array is unique or not
  #
  #  [1, 2, "a", 3].uniq? # => true
  #  [1, 2, "a", 3, "a"].uniq? # => false
  #  [].uniq? # => true
  def uniq?
    uniq == self
  end
end
