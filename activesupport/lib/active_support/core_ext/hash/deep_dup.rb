class Hash
  # Returns a deep copy of hash.
  def deep_dup
    duplicate = self.dup
    duplicate.each_pair do |k,v|
      duplicate[k] = v.is_a?(Hash) ? v.deep_dup : v
    end
    duplicate
  end
end
