module ActiveRecord
  class QueryCache #:nodoc:
    def initialize(connection)
      @connection = connection
      @query_cache = {}
    end

    def clear_query_cache
      @query_cache = {}
    end

    def select_all(sql, name = nil)
      @query_cache[sql] ||= @connection.select_all(sql, name)
    end

    def select_one(sql, name = nil)
      @query_cache[sql] ||= @connection.select_one(sql, name)
    end

    def columns(table_name, name = nil)
      @query_cache["SHOW FIELDS FROM #{table_name}"] ||= @connection.columns(table_name, name)
    end

    def insert(sql, name = nil, pk = nil, id_value = nil)
      clear_query_cache
      @connection.insert(sql, name, pk, id_value)
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
      def method_missing(method, *arguments)
        @connection.send(method, *arguments)
      end
  end
  
  class Base
    # Set the connection for the class with caching on
    def self.connection=(spec)
      raise ConnectionNotEstablished unless spec

      conn = spec.config[:query_cache] ?
        QueryCache.new(self.send(spec.adapter_method, spec.config)) :
        self.send(spec.adapter_method, spec.config)
      
      active_connections[self] = conn
    end
  end
  
  class AbstractAdapter #:nodoc:
    # Stub method to be able to treat the connection the same whether the query cache has been turned on or not
    def clear_query_cache
    end
  end
end
