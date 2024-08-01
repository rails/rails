# frozen_string_literal: true

require "active_support/deep_mergeable"

class Hash
  include ActiveSupport::DeepMergeable

  ##
  # :method: deep_merge
  # :call-seq: deep_merge(other_hash, &block)
  #
  # Returns a new hash with +self+ and +other_hash+ merged recursively.
  #
  #   h1 = { a: true, b: { c: [1, 2, 3] } }
  #   h2 = { a: false, b: { x: [3, 4, 5] } }
  #
  #   h1.deep_merge(h2) # => { a: false, b: { c: [1, 2, 3], x: [3, 4, 5] } }
  #
  # Like with Hash#merge in the standard library, a block can be provided
  # to merge values:
  #
  #   h1 = { a: 100, b: 200, c: { c1: 100 } }
  #   h2 = { b: 250, c: { c1: 200 } }
  #   h1.deep_merge(h2) { |key, this_val, other_val| this_val + other_val }
  #   # => { a: 100, b: 450, c: { c1: 300 } }
  #
  #--
  # Implemented by ActiveSupport::DeepMergeable#deep_merge.

  ##
  # :method: deep_merge!
  # :call-seq: deep_merge!(other_hash, &block)
  #
  # Same as #deep_merge, but modifies +self+.
  #
  #--
  # Implemented by ActiveSupport::DeepMergeable#deep_merge!.

  def deep_merge?(other) # :nodoc:
    other.is_a?(Hash)
  end
end
