class Hash
  # Returns a new hash with the results of running +block+ once for every value.
  # The keys are unchanged.
  #
  #   { a: 1, b: 2, c: 3 }.transform_values { |x| x * 2 }
  #   # => { a: 2, b: 4, c: 6 }
  def transform_values(&block)
    result = self.class.new
    each do |key, value|
      result[key] = yield(value)
    end
    result
  end

  # Destructive +transform_values+
  def transform_values!
    each do |key, value|
      self[key] = yield(value)
    end
  end
end
