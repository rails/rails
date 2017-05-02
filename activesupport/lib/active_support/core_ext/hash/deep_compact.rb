class Hash
  # Returns a new hash with non +nil+ values compacted recursively.
  #
  #   hash = { a: true, b: false, c: nil, d: { e: 1, f: nil } }
  #   hash.deep_compact # => { a: true, b: false, d: { e: 1 } }
  #   { c: nil }.deep_compact # => {}
  def deep_compact
    dup.deep_compact!
  end
  
  # Same as +deep_compact+, but modifies +self+.
  def deep_compact!
    self.each do |key, value|
      value.deep_compact! if value.is_a? Hash
      delete(key) if value.nil?
    end
    self
  end
end
