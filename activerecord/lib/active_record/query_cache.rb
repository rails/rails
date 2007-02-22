module ActiveRecord
  class QueryCache #:nodoc:
    def initialize(connection)
      @connection = connection
      @query_cache = {}
    end

    def clear_query_cache
      @query_cache.clear
    end

    def select_all(sql, name = nil)
      cache(sql) { @connection.select_all(sql, name) }
    end

    def select_one(sql, name = nil)
      cache(sql) { @connection.select_one(sql, name) }
    end
    
    def select_values(sql, name = nil)
      cache(sql) { @connection.select_values(sql, name) }
    end

    def select_value(sql, name = nil)
      cache(sql) { @connection.select_value(sql, name) }
    end
    
    def execute(sql, name = nil)
      clear_query_cache
      @connection.execute(sql, name)
    end    

    def columns(table_name, name = nil)
      @query_cache["SHOW FIELDS FROM #{table_name}"] ||= @connection.columns(table_name, name)
    end

    def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
      clear_query_cache
      @connection.insert(sql, name, pk, id_value, sequence_name)
    end

    def update(sql, name = nil)
      clear_query_cache
      @connection.update(sql, name)
    end

    def delete(sql, name = nil)
      clear_query_cache
      @connection.delete(sql, name)
    end
    
    private
    
      def cache(sql)
        result = if @query_cache.has_key?(sql)
          log_info(sql, "CACHE", 0.0)
          @query_cache[sql]
        else
          @query_cache[sql] = yield
        end
        
        result ? result.dup : nil
      end
    
      def method_missing(method, *arguments, &proc)
        @connection.send(method, *arguments, &proc)
      end
  end
    
  class Base
    # Set the connection for the class with caching on
    class << self
      alias_method :connection_without_query_cache, :connection
      
      def query_caches
        Thread.current["query_cache_#{connection_without_query_cache.object_id}"] ||= {}
      end
      
      def query_cache
        if query_caches[self]
          query_caches[self]
        elsif superclass.respond_to?(:query_cache) and superclass.respond_to?(:connection) and superclass.connection_without_query_cache == connection_without_query_cache
          superclass.query_cache
        end
      end
      
      def query_cache=(cache)
        query_caches[self] = cache
      end

      # Use a query cache within the given block.
      def cache
        # Don't cache if Active Record is not configured.
        if ActiveRecord::Base.configurations.blank?
          yield
        else
          begin
            self.query_cache = QueryCache.new(connection_without_query_cache)
            yield
          ensure
            self.query_cache = nil
          end
        end
      end

      def connection
        query_cache || connection_without_query_cache
      end
    end
  end  
end
