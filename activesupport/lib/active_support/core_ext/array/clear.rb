class Array
  # A friendly method name to add to `clear` and `clear!`
  alias_method :clear?,  :empty?

  # Clears the array and returns cleared elements
  #
  #   %w( a b c d ).clear!   # => ["a", "b", "c", "d"]
  #   %w().clear!            # => []
  def clear!
    array = dup
    clear
    array
  end
end
