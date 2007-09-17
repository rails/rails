module ActiveRecord
  module QueryCache
    # Enable the query cache within the block if Active Record is configured.
    def cache(&block)
      if ActiveRecord::Base.configurations.blank?
        yield
      else
        connection.cache(&block)
      end
    end

    # Disable the query cache within the block if Active Record is configured.
    def uncached(&block)
      if ActiveRecord::Base.configurations.blank?
        yield
      else
        connection.uncached(&block)
      end
    end
  end
end
