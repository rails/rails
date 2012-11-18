require 'active_support/deprecation'

module ActiveSupport
  module Testing
    module Pending
      unless defined?(Spec)
        def pending(description = "", &block)
          ActiveSupport::Deprecation.warn("#pending is deprecated and will be removed in Rails 4.1, please use #skip instead.")
          skip(description.blank? ? nil : description)
        end
      end
    end
  end
end
