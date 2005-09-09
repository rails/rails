module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Additional string tests.
      module StartsEndsWith
        # Does the string start with the specified +prefix+?
        def starts_with?(prefix)
          prefix = prefix.to_s
          self[0, prefix.length] == prefix
        end

        # Does the string end with the specified +suffix+?
        def ends_with?(suffix)
          suffix = suffix.to_s
          self[-suffix.length, suffix.length] == suffix      
        end
      end
    end
  end
end
