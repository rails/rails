# frozen_string_literal: true

module ActiveSupport
  # Provides +deep_merge+ and +deep_merge!+ methods. Expects the including class
  # to provide a <tt>merge!(other, &block)</tt> method.
  module DeepMergeable # :nodoc:
    # Returns a new instance with the values from +other+ merged recursively.
    #
    #   class Hash
    #     include ActiveSupport::DeepMergeable
    #   end
    #
    #   hash_1 = { a: true, b: { c: [1, 2, 3] } }
    #   hash_2 = { a: false, b: { x: [3, 4, 5] } }
    #
    #   hash_1.deep_merge(hash_2)
    #   # => { a: false, b: { c: [1, 2, 3], x: [3, 4, 5] } }
    #
    # A block can be provided to merge non-<tt>DeepMergeable</tt> values:
    #
    #   hash_1 = { a: 100, b: 200, c: { c1: 100 } }
    #   hash_2 = { b: 250, c: { c1: 200 } }
    #
    #   hash_1.deep_merge(hash_2) do |key, this_val, other_val|
    #     this_val + other_val
    #   end
    #   # => { a: 100, b: 450, c: { c1: 300 } }
    #
    def deep_merge(other, &block)
      dup.deep_merge!(other, &block)
    end

    # Same as #deep_merge, but modifies +self+.
    def deep_merge!(other, &block)
      merge!(other) do |key, this_val, other_val|
        if this_val.is_a?(DeepMergeable) && this_val.deep_merge?(other_val)
          this_val.deep_merge(other_val, &block)
        elsif block_given?
          block.call(key, this_val, other_val)
        else
          other_val
        end
      end
    end

    # Returns true if +other+ can be deep merged into +self+. Classes may
    # override this method to restrict or expand the domain of deep mergeable
    # values. Defaults to checking that +other+ is of type +self.class+.
    def deep_merge?(other)
      other.is_a?(self.class)
    end
  end
end
