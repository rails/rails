require 'active_support/deprecation'
require 'active_support/logger'

module ActiveSupport
  class BufferedLogger < Logger

    def initialize(*args)
      self.class._deprecation_warning
      super
    end

    def self.inherited(*)
      _deprecation_warning
      super
    end

    def self._deprecation_warning
      ::ActiveSupport::Deprecation.warn 'ActiveSupport::BufferedLogger is deprecated! Use ActiveSupport::Logger instead.'
    end
  end
end
