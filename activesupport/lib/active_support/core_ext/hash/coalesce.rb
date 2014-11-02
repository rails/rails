class Hash
  # Returns a new hash with all of the properties in the other_hashes merged to the
  # source hash. It's in-order, so the last other_hash will override properties of
  # the same name in previous arguments.
  #
  #   h1 = { a: true, b: "foo" }
  #   h2 = { c: "bar" }
  #   h3 = { b: "baz" }
  #
  #   h1.coalesce(h2, h3) #=> { a: true, b: "baz", c: "bar" }
  #
  # Like with Hash#merge in the standard library, a block can be provided
  # to merge values:
  #
  #   h1 = { a: 100, b: 200 }
  #   h2 = { c: 300 }
  #   h3 = { b: 150 }
  #
  #   h1.coalesce(h2, h3) { |key, this_val, other_val| this_val + other_val }
  #   # => { a: 100, b: 350, c: 300 }

  def coalesce(*other_hashes, &block)
    dup.coalesce!(*other_hashes, &block)
  end

  def coalesce!(*other_hashes, &block)
    other_hashes.each { |other_hash| self.merge!(other_hash, &block) }
    self
  end
end
