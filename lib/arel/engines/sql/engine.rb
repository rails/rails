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
          primary_key_value = if relation.primary_key.blank?
            nil
          elsif relation.record.is_a?(Hash)
            attribute = relation.record.detect { |attr, _| attr.name.to_s == relation.primary_key.to_s }
            attribute && attribute.last.value
          end

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
