# frozen_string_literal: true

class Hash
  # Deep merges the caller into +other_hash+. For example,
  #
  #   options = options.deep_reverse_merge(size: 25, coords: { x: 2, y: -1 })
  #
  # is equivalent to
  #
  #   options = { size: 25, coords: { x: 2, y: -1 } }.deep_merge(options)
  #
  # This is particularly useful for initializing an options hash
  # with default values.
  def deep_reverse_merge(other_hash)
    other_hash.deep_merge(self)
  end

  # Same as +deep_reverse_merge+, but modifies +self+.
  def deep_reverse_merge!(other_hash)
    replace(deep_reverse_merge(other_hash))
  end
end
