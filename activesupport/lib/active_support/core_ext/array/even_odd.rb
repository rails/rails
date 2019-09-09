# frozen_string_literal: true

class Array
  # Check if the array has an even number of elements.
  #
  #   %w( a b c d ).even? # => true
  #   %w( a b c ).even?   # => false
  def even?
    self.length.even?
  end

  # Check if the array has an odd number of elements.
  #
  #   %w( a b c ).odd?   # => true
  #   %w( a b c d ).odd? # => false
  def odd?
    self.length.odd?
  end
end
