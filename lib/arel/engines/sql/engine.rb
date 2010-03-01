module Arel
  module Sql
    class Engine

      def initialize(ar = nil)
        @ar = ar
      end

      def connection
        @ar ? @ar.connection : nil
      end

      def adapter_name
        @adapter_name ||= case (name = connection.adapter_name)
        # map OracleEnanced adapter to Oracle
        when /Oracle/
          'Oracle'
        else
          name
        end
      end

      def method_missing(method, *args, &block)
        @ar.connection.send(method, *args, &block)
      end

      module CRUD
        def create(relation)
          attribute = [*relation.record].map do |attr, value|
            if attr.respond_to?(:name) && !relation.primary_key.blank? && attr.name == relation.primary_key
              value
            end
          end.compact.first
          primary_key_value = attribute ? attribute.value : nil
          connection.insert(relation.to_sql(false), nil, relation.primary_key, primary_key_value)
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
