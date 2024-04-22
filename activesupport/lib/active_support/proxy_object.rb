# frozen_string_literal: true

module ActiveSupport
  # = Active Support Proxy \Object
  #
  # A class with no predefined methods that behaves similarly to Ruby's
  # BasicObject. Used for proxy classes.
  class ProxyObject < ::BasicObject
    undef_method :==
    undef_method :equal?

    # Let ActiveSupport::ProxyObject at least raise exceptions.
    def raise(*args)
      ::Object.send(:raise, *args)
    end
  end
end
