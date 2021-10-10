# frozen_string_literal: true

class Hash
  # Returns an Array all values at the leaf nodes of the Hash.
  #
  #   hash = {
  #     name: 'Sam',
  #     sister: {
  #       name: 'Sarah',
  #       age: 32,
  #       pet: {
  #         type: 'Dog'
  #       }
  #     }
  #   }
  #
  #   hash.leaf_values
  #   # => ['Sam', 'Sarah', 32, 'Dog']
  def leaf_values
    keys.flat_map do |k|
      if self[k].is_a?(Hash)
        self[k].leaf_values
      else
        self[k]
      end
    end
  end
end