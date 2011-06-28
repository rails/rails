class Array
  # Returns an unique array based on the criteria given as a +Proc+.
  #
  #   [1, 2, 3, 4].uniq_by { |i| i.odd? } # => [1, 2]
  #
  def uniq_by
    hash, array = {}, []
    each { |i| hash[yield(i)] ||= (array << i) }
    array
  end

  # Same as uniq_by, but modifies self.
  def uniq_by!
    replace(uniq_by{ |i| yield(i) })
  end
end
