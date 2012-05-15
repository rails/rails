class Hash
  # Returns a new hash with +self+ and +other_hash+ merged recursively.
  #
  #   h1 = {:x => {:y => [4,5,6]}, :z => [7,8,9]}
  #   h2 = {:x => {:y => [7,8,9]}, :z => "xyz"}
  #
  #   h1.deep_merge(h2) #=> { :x => {:y => [7, 8, 9]}, :z => "xyz" }
  #   h2.deep_merge(h1) #=> { :x => {:y => [4, 5, 6]}, :z => [7, 8, 9] }
  def deep_merge(other_hash)
    dup.deep_merge!(other_hash)
  end

  # Same as +deep_merge+, but modifies +self+.
  def deep_merge!(other_hash)
    other_hash.each_pair do |k,v|
      tv = self[k]
      self[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? tv.deep_merge(v) : v
    end
    self
  end
end
