require 'active_support/deprecation'
require 'active_support/logger'

module ActiveSupport
  class BufferedLogger < Logger
    def self.inherited(*)
      ::ActiveSupport::Deprecation.warn 'ActiveSupport::BufferedLogger is deprecated! Use ActiveSupport::Logger instead.'
      super
    end
  end
end
