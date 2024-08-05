# frozen_string_literal: true

module ActiveSupport
  class ProxyObject < ::BasicObject # :nodoc:
    undef_method :==
    undef_method :equal?

    # Let ActiveSupport::ProxyObject at least raise exceptions.
    def raise(*args)
      ::Object.send(:raise, *args)
    end

    def self.inherited(_subclass)
      ::ActiveSupport.deprecator.warn(<<~MSG)
        ActiveSupport::ProxyObject is deprecated and will be removed in Rails 8.0.
        Use Ruby's built-in BasicObject instead.
      MSG
    end
  end
end
