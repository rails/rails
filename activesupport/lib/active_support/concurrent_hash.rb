module ActiveSupport
  class ConcurrentHash
    def initialize(hash = {})
      @backup_cache = hash.dup
      @frozen_cache = hash.dup.freeze
      @mutex = Mutex.new
    end

    def []=(k,v)
      @mutex.synchronize { @backup_cache[k] = v }
      @frozen_cache = @backup_cache.dup.freeze
      v
    end

    def [](k)
      if @frozen_cache.key?(k)
        @frozen_cache[k]
      else
        @mutex.synchronize { @backup_cache[k] }
      end
    end

    def empty?
      @backup_cache.empty?
    end
  end
end
