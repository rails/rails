require 'active_support/deprecation'
require 'active_support/proxy_object'

module ActiveSupport
  class BasicObject < ProxyObject # :nodoc:
    def self.inherited(*)
      ::ActiveSupport::Deprecation.warn 'ActiveSupport::BasicObject is deprecated! Use ActiveSupport::ProxyObject instead.'
      super
    end
  end
end
