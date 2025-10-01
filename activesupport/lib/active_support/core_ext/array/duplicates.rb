# frozen_string_literal: true

class Array
  # Returns true if the array contains any duplicate elements.
  #   [1, 2, 3].duplicates?    # => false
  #   [1, 2, 3, 1].duplicates? # => true
  def duplicates?
    seen = Set.new
    each do |e|
      return true if seen.add?(e).nil?
    end

    false
  end
end
