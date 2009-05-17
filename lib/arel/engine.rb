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

    module CRUD
      def create(relation)
        connection.insert(relation.to_sql)
      end

      def read(relation)
        results = connection.execute(relation.to_sql)
        rows = []
        results.each do |row|
          rows << attributes.zip(row).to_hash
        end
        rows
      end

      def update(relation)
        connection.update(relation.to_sql)
      end

      def delete(relation)
        connection.delete(relation.to_sql)
      end
    end
    include CRUD
  end
end
