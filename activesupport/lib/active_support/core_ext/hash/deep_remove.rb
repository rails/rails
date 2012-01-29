class Hash
  # Returns a new hash with keys and nested keys indicated by +key_hash+ removed.
  # Example:
  #
  #   h = { :a => 1, :b => { :c => 2, :d => 3 }, :e => 4 }
  #   kh = { :a => true, :b => { :c => true } }
  #   h.deep_remove(kh)
  #   # => { :b => { :d => 3}, :e => 4 }
  def deep_remove(key_hash)
    new_hash = self.class.new
    each_pair do |k,v|
      unless key_hash.has_key?(k) && ov = key_hash[k]
        new_hash[k] = v.is_a?(Hash) ? v.deep_dup : v
      else
        new_hash[k] = v.deep_remove(ov) if ov.is_a?(Hash)
      end
    end
    new_hash
  end

  # Returns a new hash with keys and nested keys indicated by +key_hash+ removed.
  # Modifies the receiver in place.
  def deep_remove!(key_hash)
    key_hash.each_pair do |k,ov|
      if ov
        if ov.is_a?(Hash)
          self[k].deep_remove!(ov)
        else
          delete(k)
        end
      end
    end
    self
  end
end
