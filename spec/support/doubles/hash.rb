class Hash
  def ordered_array
    to_a.sort { |(key1, value1), (key2, value2)| key1.hash <=> key2.hash }
  end

  undef :keys
  def keys
    ordered_array.collect(&:first)
  end

  undef :values
  def values
    ordered_array.collect { |_, v| v }
  end

  undef :each
  def each(&block)
    ordered_array.each(&block)
  end

  undef :shift
  def shift
    returning to_a.first do |k, v|
      delete(k)
    end
  end
end
