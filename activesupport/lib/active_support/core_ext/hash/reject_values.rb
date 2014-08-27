class Hash
  # Returns a new hash without the results of running +block+ once for every value that evaluate to true.
  #
  #   { a: 1, b: 2, c: 3 }.reject_values(&:odd?)
  #   # => { b: 2 }
  def reject_values
    return enum_for(:reject_values) unless block_given?
    result = self.class.new
    each do |key, value|
      result[key] = value unless yield(value)
    end
    result
  end

  # Destructive +reject_values+
  def reject_values!
    return enum_for(:reject_values!) unless block_given?
    each do |key, value|
      self.delete(key) if yield(value)
    end
  end
end
