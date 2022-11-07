# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/deep_dup"

class Array
  # Returns a new array with flipped element. This method doesn't modify +self+.
  #
  #   ary = ["a", "b", "c", "d"]
  #
  #   ary.flip(0, 3)
  #   # => ["d", "b", "c", "a"]
  #
  #   ary
  #   # => ["a", "b", "c", "d"]
  def flip(from, to)
    new_ary = deep_dup

    _flip_object_elements!(new_ary, from, to)
  end

  # Same as +flip+, but modifies +self+.
  #
  #   ary = ["a", "b", "c", "d"]
  #
  #   ary.flip!(0, 3)
  #   # => ["d", "b", "c", "a"]
  #
  #   ary
  #   # => ["d", "b", "c", "a"]
  #
  # Return +nil+ if +from+ and +to+ positions are the same.
  #
  #   ary.flip!(0, 0)
  #   # => nil
  #
  #   ary.flip!(-1, 3)
  #   # => nil
  def flip!(from, to)
    _flip_object_elements!(self, from, to) do
      return if from == to
      return if from.negative? && !to.negative? && from.abs + to == size
      return if to.negative? && !from.negative? && to.abs + from == size
    end
  end
end
