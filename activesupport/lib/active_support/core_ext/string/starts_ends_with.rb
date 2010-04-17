module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Additional string tests.
      module StartsEndsWith
        def self.append_features(base)
          if '1.8.7 and up'.respond_to?(:start_with?)
            base.class_eval do
              alias_method :starts_with?, :start_with?
              alias_method :ends_with?, :end_with?
            end
          else
            super
            base.class_eval do
              alias_method :start_with?, :starts_with?
              alias_method :end_with?, :ends_with?
            end
          end
        end

        # Does the string start with the specified +prefix+?
        def starts_with?(prefix)
          prefix.respond_to?(:to_str) && self[0, prefix.length] == prefix
        end

        # Does the string end with the specified +suffix+?
        def ends_with?(suffix)
          suffix.respond_to?(:to_str) && self[-suffix.length, suffix.length] == suffix
        end
      end
    end
  end
end
