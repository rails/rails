module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Additional string tests.
      module StartsEndsWith
        def self.append_features(base)
          base.class_eval do
            alias_method :starts_with?, :start_with?
            alias_method :ends_with?, :end_with?
          end
        end
      end
    end
  end
end
