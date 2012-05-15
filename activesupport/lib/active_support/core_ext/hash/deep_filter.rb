class Hash
  # Returns a new hash where only keys and nested keys indicated by +key_hash+ are kept.
  # Example:
  #
  #   h = { :a => 1, :b => { :c => 2, :d => 3 }, :e => 4 }
  #   kh = { :a => true, :b => { :c => true } }
  #   h.deep_filter(kh)
  #   # => { :a => 1, :b => { :c => 2} }
  def deep_filter(key_hash)
    new_hash = self.class.new
    each_pair do |k,v|
      if ov = key_hash[k]
        new_hash[k] = ov.is_a?(Hash) ? v.deep_filter(ov) : (v.is_a?(Hash) ? v.deep_dup : v)
      end
    end
    new_hash
  end

  # Returns a new hash where only keys and nested keys indicated by +key_hash+ are kept.
  # Modifies the receiver in place.
  def deep_filter!(key_hash)
    each_pair do |k,v|
      if ov = key_hash[k]
        v.deep_filter!(ov) if ov.is_a?(Hash)
      else
        delete(k)
      end
    end
    self
  end
end
