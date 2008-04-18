module Arel
  # this file is currently just a hack to adapt between activerecord::base which holds the connection specification
  # and active relation. ultimately, this file should be in effect what the connection specification is in active record;
  # that is: a spec of the database (url, password, etc.), a quoting adapter layer, and a connection pool.
  class Engine
    def initialize(ar = nil)
      @ar = ar
    end
    
    def connection
      @ar.connection
    end
    
    def method_missing(method, *args, &block)
      @ar.connection.send(method, *args, &block)
    end
  end
end