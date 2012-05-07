class Object
  # Returns a deep copy of object if it's duplicable.
  def deep_dup
    duplicable? ? dup : self
  end
end

class Array
  # Returns a deep copy of array.
  def deep_dup
    map { |it| it.deep_dup }
  end
end

class Hash
  # Returns a deep copy of hash.
  def deep_dup
    each_with_object(dup) do |(key, value), hash|
      hash[key.deep_dup] = value.deep_dup
    end
  end
end
