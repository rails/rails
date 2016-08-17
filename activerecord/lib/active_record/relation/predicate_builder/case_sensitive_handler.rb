module ActiveRecord
  class PredicateBuilder
    class CaseSensitiveHandler # :nodoc:
      def call(attribute, value)
        value.call(attribute)
      end

      class Value < Struct.new(:value, :table, :case_sensitive?) # :nodoc:
        def call(attribute)
          klass = table.send(:klass)
          column = klass.column_for_attribute(attribute.name)
          if case_sensitive?
            klass.connection.case_sensitive_comparison(attribute, column, value)
          else
            klass.connection.case_insensitive_comparison(attribute, column, value)
          end
        end
      end
    end
  end
end
