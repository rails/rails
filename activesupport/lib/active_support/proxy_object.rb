# frozen_string_literal: true

module ActiveSupport
  # = Active Support Proxy \Object
  #
  # A class with no predefined methods that behaves similarly to Builder's
  # BlankSlate. Used for proxy classes.
  class ProxyObject < ::BasicObject
    undef_method :==
    undef_method :equal?

    # Let ActiveSupport::ProxyObject raise exceptions.
    def raise(*args)
      ::Object.send(:raise, *args)
    end

    # Let ActiveSupport::ProxyObject use "block_given?"".
    def block_given?
      ::Object.send(:block_given?)
    end
  end
end
