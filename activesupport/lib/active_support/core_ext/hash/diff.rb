class Hash
  # Returns a hash that represents the difference between two hashes.
  #
  #   { 1 => 2 }.diff(1 => 2)         # => {}
  #   { 1 => 2 }.diff(1 => 3)         # => { 1 => 2 }
  #   {}.diff(1 => 2)                 # => { 1 => 2 }
  #   { 1 => 2, 3 => 4 }.diff(1 => 2) # => { 3 => 4 }
  def diff(other)
    dup.
      delete_if { |k, v| other[k] == v }.
      merge!(other.dup.delete_if { |k, v| has_key?(k) })
  end

  # Returns a hash that represents the recursive difference between two hashes.
  #
  #   { a: { b: 1 } }.deep_diff(a: { b: 1 })       # => {}
  #   { a: { b: 1, c: 2 } }.deep_diff(a: { b: 1 }) # => { a: { c: 2 } }
  #   { a: { b: 1 } }.deep_diff(a: { b: 1, c: 2 }) # => { a: { c: 2 } }
  def deep_diff(other)
    diff = {}
    other_diff = other.dup

    each_pair do |k,v|
      if v.is_a?(Hash) && other[k].is_a?(Hash)
        h = v.deep_diff(other[k])
        diff[k] = h unless h.empty?
      elsif v != other[k]
        diff[k] = v
      end
      other_diff.delete(k)
    end

    diff.merge!(other_diff)
  end
end
