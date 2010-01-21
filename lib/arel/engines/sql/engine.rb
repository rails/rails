module Arel
  module Sql
    class Engine
      def initialize(ar = nil)
        @ar = ar
      end

      def connection
        @ar.connection
      end

      def adapter_name
        @adapter_name ||= connection.adapter_name
      end

      def method_missing(method, *args, &block)
        @ar.connection.send(method, *args, &block)
      end

      module CRUD
        def create(relation)
          connection.insert(relation.to_sql)
        end

        def read(relation)
          rows = connection.select_rows(relation.to_sql)
          Array.new(rows, relation.attributes)
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
end
