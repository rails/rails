# frozen_string_literal: true

class Array
  # Removes and returns the elements for which the block returns a true value.
  # If no block is given, an Enumerator is returned instead.
  #
  #   numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  #   odd_numbers = numbers.extract! { |number| number.odd? } # => [1, 3, 5, 7, 9]
  #   numbers # => [0, 2, 4, 6, 8]
  def extract!(&block)
    unless block_given?
      to_enum(:extract!) { size }
    else
      extracted_elements, other_elements = partition(&block)

      replace(other_elements)

      extracted_elements
    end
  end
end
