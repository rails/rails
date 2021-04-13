# frozen_string_literal: true

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
    deep_dup_hashes(self).deep_merge!(other_hash, &block)
  end

  # Same as +deep_merge+, but modifies +self+.
  def deep_merge!(other_hash, &block)
    merge!(deep_dup_hashes(other_hash)) do |key, this_val, other_val|
      if this_val.is_a?(Hash) && other_val.is_a?(Hash)
        this_val.deep_merge(other_val, &block)
      elsif block_given?
        block.call(key, this_val, other_val)
      else
        other_val
      end
    end
  end

  private
    def deep_dup_hashes(object)
      return object unless object.is_a?(Hash)

      copy = object.transform_keys { |k| deep_dup_hashes(k) }
      copy.transform_values! { |v| deep_dup_hashes(v) }
      copy
    end
end
