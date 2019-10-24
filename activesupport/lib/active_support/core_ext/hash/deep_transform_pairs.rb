# frozen_string_literal: true

class Hash
  # Returns a new hash with all keys and values converted by a pair of block operations.
  # This includes the keys and values from the root hash and from all
  # nested hashes and arrays.
  #
  #  hash = { person: { name: 'Bobby', age: '21' } }
  #
  #  hash.deep_transform_pairs(
  #    key_block: -> (k) { k.to_s.upcase },
  #    value_block: -> (v) { v.to_s.upcase }
  #  )
  # => {"PERSON": {"NAME": "BOBBY", "AGE": "21"}}
  def deep_transform_pairs(key_block:, value_block:)
    _deep_transform_pairs_in_object(self, key_block, value_block)
  end

  # Destructively converts all keys and values by using a pair of block operations.
  # This includes the values from the root hash and from all
  # nested hashes and arrays.
  def deep_transform_pairs!(key_block:, value_block:)
    _deep_transform_pairs_in_object!(self, key_block, value_block)
  end

  private
    # Support methods for deep transforming nested hashes and arrays.
    def _deep_transform_pairs_in_object(object, key_block, value_block)
      case object
      when Hash
        object.each_with_object({}) do |(key, value), result|
          result[key_block.call(key)] = _deep_transform_pairs_in_object(value, key_block, value_block)
        end
      when Array
        object.map { |e| _deep_transform_pairs_in_object(e, key_block, value_block) }
      else
        value_block.call(object)
      end
    end

    def _deep_transform_pairs_in_object!(object, key_block, value_block)
      case object
      when Hash
        object.keys.each do |key|
          value = object.delete(key)
          object[key_block.call(key)] = _deep_transform_pairs_in_object!(value, key_block, value_block)
        end
        object
      when Array
        object.map! { |e| _deep_transform_pairs_in_object!(e, key_block, value_block) }
      else
        value_block.call(object)
      end
    end
end
