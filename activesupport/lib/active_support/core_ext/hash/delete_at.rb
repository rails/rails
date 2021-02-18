# frozen_string_literal: true

class Hash
  # From a list of keys, delete and return their corresponding values as an
  # Array. Mirros the `Hash#values_at` interfaces, and pairs nicely with
  # multiple assignment.
  #
  #   hash = { a: true, b: false, c: nil }
  #   a, c = hash.delete_at(:a, :c) # => [ true, nil ]
  #   hash # => { b: false }
  #
  def delete_at(*keys, &block)
    block ||= default_proc

    keys.map { |key| delete(key, &block) || default }
  end unless method_defined?(:delete_at)
end
