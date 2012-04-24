class Object
  # Returns a deep copy of object if it's duplicable.
  def deep_dup
    duplicable? ? dup : self
  end
end
