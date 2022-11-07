# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/deep_dup"
require "active_support/hash_with_indifferent_access"

class Hash
  # Returns a new hash with flipped element. This method doesn't modify +self+.
  #
  #   hsh = { a: 1, b: 2, c: 3 }
  #
  #   hsh.flip(:a, :b)
  #   # => { a: 2, b: 1, c: 3 }
  #
  #   hsh
  #   # => { a: 1, b: 2, c: 3 }
  def flip(from, to)
    new_hsh = deep_dup

    _flip_object_elements!(new_hsh, from, to)
  end

  # Same as +flip+, but modifies +self+.
  #
  #   hsh = { a: 1, b: 2, c: 3 }
  #
  #   hsh.flip!(:a, :b)
  #   # => { a: 2, b: 1, c: 3 }
  #
  #   hsh
  #   # => { a: 2, b: 1, c: 3 }
  #
  # Return +nil+ if +from+ and +to+ keys are the same.
  #
  #   hsh.flip!(:a, :a)
  #   # => nil
  #
  #   hsh.with_indifferent_access.flip!("a", :a)
  #   # => nil
  def flip!(from, to)
    _flip_object_elements!(self, from, to) do
      return if from == to
      return if is_a?(ActiveSupport::HashWithIndifferentAccess) && convert_key(from) == convert_key(to)
    end
  end
end
