module ActiveSupport
  module Cache
    # Like MemoryStore, but thread-safe.
    class SynchronizedMemoryStore < MemoryStore
      def initialize(*args)
        ActiveSupport::Deprecation.warn('ActiveSupport::Cache::SynchronizedMemoryStore has been deprecated in favor of ActiveSupport::Cache::MemoryStore.', caller)
        super
      end
    end
  end
end
