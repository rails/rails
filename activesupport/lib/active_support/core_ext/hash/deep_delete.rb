# frozen_string_literal: true

class Hash
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
