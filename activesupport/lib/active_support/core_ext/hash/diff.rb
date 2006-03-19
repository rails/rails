module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module Diff
        def diff(h2)
          self.dup.delete_if { |k, v| h2[k] == v }.merge(h2.dup.delete_if { |k, v| self.has_key?(k) })
        end
      end
    end
  end
end
