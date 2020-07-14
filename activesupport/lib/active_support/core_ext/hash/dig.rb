# frozen_string_literal: true

class Hash
  # Retrieves the value object corresponding to the each key objects repeatedly
  # Raises when a key is missing
  #
  #   hash = { a: { b: { c: 3 } } }
  #   hash.dig!(:a, :b, :c)  # => 3
  #   hash.dig!(:a, :z, :c)  # => KeyError: key not found: :z
  def dig!(*keys)
    keys.reduce(self) do |result, key|
      result.fetch(key)
    end
  end
end
