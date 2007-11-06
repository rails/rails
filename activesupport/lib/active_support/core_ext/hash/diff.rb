module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module Diff
        # Returns a hash that represents the difference between two hashes.
        #
        # Examples:
        #
        #   {1 => 2}.diff(1 => 2)         # => {}
        #   {1 => 2}.diff(1 => 3)         # => {1 => 2}
        #   {}.diff(1 => 2)               # => {1 => 2}
        #   {1 => 2, 3 => 4}.diff(1 => 2) # => {3 => 4}
        def diff(h2)
          self.dup.delete_if { |k, v| h2[k] == v }.merge(h2.dup.delete_if { |k, v| self.has_key?(k) })
        end
      end
    end
  end
end
