class Symbol

  #Returns a lambda with partially applied parameters for use with Enumerable#map
  #and other methods which take a proc.
  #
  #  a = [1,3,5,7,9]
  #  a.map(&:+.with(2)) # => [3, 5, 7, 9, 11]
  #
  #Can be used with multiple parameters:
  #
  #  arr = ["abc", "babc", "great", "fruit"]
  #  arr.map(&:center.with(20, '*')) # => ["********abc*********", 
  #                                  #     "********babc********",
  #                                  #     "*******great********", 
  #                                  #     "*******fruit********"]
  #
  #And on nested proc calls as well:
  #
  #  [['0', '1'], ['2', '3']].map(&:map.with(&:to_i)) # => [[0, 1], [2, 3]]
  #  [%w(a b), %w(c d)].map(&:inject.with(&:+))       # => ["ab", "cd"] 
  #  [(1..5), (6..10)].map(&:map.with(&:*.with(2)))   # => [[2, 4, 6, 8, 10], [12, 14, 16, 18, 20]] 
  def with(*args, &block)
    ->(caller, *rest) { caller.send(self, *rest, *args, &block) }
  end

end
