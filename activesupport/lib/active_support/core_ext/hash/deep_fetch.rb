class Hash
  # Returns a value obtained by traversing a hash structure by a given keys.
  #
  # hash = { a: { b: 1 } }
  # hash.deep_fetch(:a, :b) # => 1
  #
  # If hash does not have a key a KeyError is raised.
  # If previously retrieved value is not a Hash a NoMethodError is raised.
  def deep_fetch(*keys)
    keys.reduce(self) do |hash, key|
      hash.fetch(key)
    end
  end
end
