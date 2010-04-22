module ActiveSupport
  module Cache
    class CompressedMemCacheStore < MemCacheStore
      def initialize(*args)
        ActiveSupport::Deprecation.warn('ActiveSupport::Cache::CompressedMemCacheStore has been deprecated in favor of ActiveSupport::Cache::MemCacheStore(:compress => true).', caller)
        addresses = args.dup
        options = addresses.extract_options!
        args = addresses + [options.merge(:compress => true)]
        super(*args)
      end
    end
  end
end
