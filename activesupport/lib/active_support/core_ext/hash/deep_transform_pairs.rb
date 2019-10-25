# frozen_string_literal: true

class Hash
  # Returns a new hash with all keys and values converted by a pair of block operations.
  # This includes the keys and values from the root hash and from all
  # nested hashes and arrays.
  #
  #  hash = { person: { name: 'Bobby', age: '21' } }
  #
  #  hash.deep_transform_pairs(
  #    key_block: -> (key) { key.to_s.upcase },
  #    value_block: -> (value) { value.to_s.upcase }
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

  # Returns a new hash with all keys and values converted by a pair of nested block
  # operations. This includes the keys and values from the root hash and from all
  # nested hashes and arrays. If either `on_key` or `on_value` are not called the
  # respective value is returned, unchanged.
  #
  #  hash = { person: { name: 'Bobby', age: '21' } }
  #
  #  hash.deep_transform_pairs_v2 do
  #    on_key do |key|
  #      key.to_s.upcase
  #    end
  #
  #    on_value do |value|
  #      value.to_s.upcase
  #    end
  #  end
  # => {"PERSON": {"NAME": "BOBBY", "AGE": "21"}}
  def deep_transform_pairs_v2(&block)
    helper = DeepTransformPairsHelper.new
    helper.instance_exec(&block)
    _deep_transform_pairs_in_object(self, helper.key_block, helper.value_block)
  end

  # Destructively converts all keys and values by using a block
  # containing nested `on_key` and `on_value` operations.
  # This includes the values from the root hash and from all
  # nested hashes and arrays. If either `on_key` or `on_value`
  # are not called the respective value is returned, unchanged.
  def deep_transform_pairs_v2!(&block)
    helper = DeepTransformPairsHelper.new
    helper.instance_exec(&block)
    _deep_transform_pairs_in_object!(self, helper.key_block, helper.value_block)
  end

  class DeepTransformPairsHelper
    attr_reader :key_block, :value_block

    def initialize
      @key_block = pass_through_block
      @value_block = pass_through_block
    end

    def on_key(&key_block)
      @key_block = key_block
    end

    def on_value(&value_block)
      @value_block = value_block
    end

    private
      def pass_through_block
        @pass_through_block ||= -> (key_or_value) { key_or_value }
      end
  end
  private_constant :DeepTransformPairsHelper

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
