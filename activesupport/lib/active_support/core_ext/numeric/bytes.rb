module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Numeric #:nodoc:
      # Enables the use of byte calculations and declarations, like 45.bytes + 2.6.megabytes
      module Bytes
        def bytes
          self
        end
        alias :byte :bytes

        def kilobytes
          self * 1024
        end
        alias :kilobyte :kilobytes

        def megabytes
          self * 1024.kilobytes
        end
        alias :megabyte :megabytes

        def gigabytes
          self * 1024.megabytes 
        end
        alias :gigabyte :gigabytes

        def terabytes
          self * 1024.gigabytes
        end
        alias :terabyte :terabytes
        
        def petabytes
          self * 1024.terabytes
        end
        alias :petabyte :petabytes
        
        def exabytes
          self * 1024.petabytes
        end
        alias :exabyte :exabytes
        
      end
    end
  end
end
