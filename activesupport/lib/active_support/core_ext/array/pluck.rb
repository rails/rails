class Array
  # Extracts values from array of hashes.
  #
  #   x = [{ a: 1, b: 2 }, { a: 10, b: 20 }]
  #
  #   instead of
  #   x.map { |h| h[:a] }
  #
  #   x.pluck(:a) => [1, 10]
  #   x.pluck(:a, :b) => [[1, 2], [10, 20]]
  def pluck(*keys)
    if keys.size > 1
      map do |hash|
        keys.map { |key| hash[key] }
      end
    else
      map { |hash| hash[keys.first] }
    end
  end
end
