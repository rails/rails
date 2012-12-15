require 'active_support/deprecation'
require 'active_support/proxy_object'

module ActiveSupport
  # :nodoc:
  class BasicObject < ProxyObject
    def self.inherited(*)
      ::ActiveSupport::Deprecation.warn 'ActiveSupport::BasicObject is deprecated! Use ActiveSupport::ProxyObject instead.'
      super
    end
  end
end
