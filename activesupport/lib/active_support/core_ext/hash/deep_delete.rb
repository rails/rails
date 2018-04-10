# frozen_string_literal: true

class Hash
  # Method provides recursive removing a pairs by keys list with nesting ignore.
  # Returns a self with removed pairs.
  #
  #    h = { a: 1, b: { c: 2 } }
  #    h.deep_delete(:c)
  #    h
  #    # => { a: 1, b: {} }
  #
  # Method can take an 1+ arguments.
  def deep_delete(*keys)
    raise ArgumentError, "wrong number of arguments (0 for 1+)" if keys.blank?

    tap do |data|
      keys.each { |key| process_data(data, key) }
    end
  end

  private

  def process_delete_by_key(data, key)
    data.delete(key) if data.key?(key)

    data.each_value { |value| process_data(value, key) }
  end

  def process_data(data, key)
    data.is_a?(Hash) ? process_delete_by_key(data, key) : data
  end
end
