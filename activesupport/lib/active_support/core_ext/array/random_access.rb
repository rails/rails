module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module RandomAccess
        # Return a random element from the array.
        def rand
          self[Kernel.rand(length)]
        end
      end
    end
  end
end
