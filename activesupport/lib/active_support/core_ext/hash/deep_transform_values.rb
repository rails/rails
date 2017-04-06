# frozen_string_literal: true

require "active_support/deep_transform_object"

class Hash
  # Returns a new hash with all values converted by the block operation.
  # This includes the values from the root hash and from all
  # nested hashes and arrays.
  #
  #  hash = { person: { name: 'Rob', age: '28' } }
  #
  #  hash.deep_transform_values{ |value| value.to_s.upcase }
  #  # => {person: {name: "ROB", age: "28"}}
  def deep_transform_values(&block)
    ActiveSupport::DeepTransformObject.deep_transform_values(self, &block)
  end

  # Destructively converts all values by using the block operation.
  # This includes the values from the root hash and from all
  # nested hashes and arrays.
  def deep_transform_values!(&block)
    ActiveSupport::DeepTransformObject.deep_transform_values!(self, &block)
  end
end
