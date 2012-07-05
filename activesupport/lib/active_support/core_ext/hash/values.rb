class Hash
  # Return a new hash with all values converted using the block operation.
  #
  #  hash = { year: '2012', month: '12' }
  #
  #  hash.transform_values{ |value| value.to_i }
  #  # => { year: 2012, month: 12 }
  def transform_values
    # use this approach instead of dup.transform_values!(&block )
    # for performance reason, see https://gist.github.com/d0d3f89e34d3fa654941
    result = {}
    each_key do |key|
      result[key] = yield(self[key])
    end
    result
  end

  # Destructively convert all values using the block operations.
  # Same as transform_values but modifies +self+
  def transform_values!
    keys.each do |key|
      self[key] = yield(delete(key))
    end
    self
  end
end
