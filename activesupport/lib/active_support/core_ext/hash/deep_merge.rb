class Hash
  # Returns a new hash with +self+ and +other_hash+ merged recursively.
  #
  #   h1 = { a: true, b: { c: [1, 2, 3] } }
  #   h2 = { a: false, b: { x: [3, 4, 5] } }
  #
  #   h1.deep_merge(h2) # => { a: false, b: { c: [1, 2, 3], x: [3, 4, 5] } }
  #
  # Like with Hash#merge in the standard library, a block can be provided
  # to merge values:
  #
  #   h1 = { a: 100, b: 200, c: { c1: 100 } }
  #   h2 = { b: 250, c: { c1: 200 } }
  #   h1.deep_merge(h2) { |key, this_val, other_val| this_val + other_val }
  #   # => { a: 100, b: 450, c: { c1: 300 } }
  def deep_merge(other_hash, &block)
    dup.deep_merge!(other_hash, &block)
  end

  # Same as +deep_merge+, but modifies +self+.
  def deep_merge!(other_hash, &block)
    other_hash.each_pair do |current_key, other_value|
      this_value = self[current_key]

      self[current_key] = if this_value.is_a?(Hash) && other_value.is_a?(Hash)
        this_value.deep_merge(other_value, &block)
      else
        if block_given? && key?(current_key)
          block.call(current_key, this_value, other_value)
        else
          other_value
        end
      end
    end

    self
  end
end
