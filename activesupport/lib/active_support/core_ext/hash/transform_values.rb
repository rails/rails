class Hash
  # Returns a new hash with the results of running +block+ once for every value.
  # The keys are unchanged.
  #
  #   { a: 1, b: 2, c: 3 }.transform_values { |x| x * 2 }
  #   # => { a: 2, b: 4, c: 6 }
  def transform_values
    return enum_for(:transform_values) unless block_given?
    result = self.class.new
    each do |key, value|
      result[key] = yield(value)
    end
    result
  end unless method_defined? :transform_values

  # Destructive +transform_values+
  def transform_values!
    return enum_for(:transform_values!) unless block_given?
    each do |key, value|
      self[key] = yield(value)
    end
  end unless method_defined? :transform_values!
end
