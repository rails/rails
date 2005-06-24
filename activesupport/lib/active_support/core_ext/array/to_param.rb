module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module ToParam #:nodoc:
        # When an array is given to url_for, it is converted to a slash separated string.
        def to_param
          join '/'
        end
      end
    end
  end
end
