require 'active_support/concern'
require 'thread_safe'

module ActiveSupport
  module LoggerThreadSafeLevel
    extend ActiveSupport::Concern

    def after_initialize
      @local_levels = ThreadSafe::Cache.new
    end

    def local_log_id
      Thread.current.__id__
    end

    def local_level
      @local_levels[local_log_id]
    end

    def local_level=(level)
      if level
        @local_levels[local_log_id] = level
      else
        @local_levels.delete(local_log_id)
      end
    end

    def level
      local_level || super
    end
  end
end
