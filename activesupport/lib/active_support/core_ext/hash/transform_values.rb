class Hash
  # Returns a new hash with the results of running +block+ once for every value.
  # The keys are unchanged.
  #
  #   { a: 1, b: 2, c: 3 }.transform_values { |x| x * 2 } # => { a: 2, b: 4, c: 6 }
  #
  # If you do not provide a +block+, it will return an Enumerator
  # for chaining with other methods:
  #
  #   { a: 1, b: 2 }.transform_values.with_index { |v, i| [v, i].join.to_i } # => { a: 10, b: 21 }
  def transform_values
    return enum_for(:transform_values) { size } unless block_given?
    return {} if empty?
    result = self.class.new
    each do |key, value|
      result[key] = yield(value)
    end
    result
  end unless method_defined? :transform_values

  # Destructively converts all values using the +block+ operations.
  # Same as +transform_values+ but modifies +self+.
  def transform_values!
    return enum_for(:transform_values!) { size } unless block_given?
    each do |key, value|
      self[key] = yield(value)
    end
  end unless method_defined? :transform_values!
end
