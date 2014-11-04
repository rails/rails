module ActiveRecord
  module Sanitization
    extend ActiveSupport::Concern

    module ClassMethods
      def quote_value(value, column) #:nodoc:
        connection.quote(value, column)
      end

      # Used to sanitize objects before they're used in an SQL SELECT statement. Delegates to <tt>connection.quote</tt>.
      def sanitize(object) #:nodoc:
        connection.quote(object)
      end

      protected

      # Accepts an array, hash, or string of SQL conditions and sanitizes
      # them into a valid SQL fragment for a WHERE clause.
      #   ["name='%s' and group_id='%s'", "foo'bar", 4]  returns  "name='foo''bar' and group_id='4'"
      #   { name: "foo'bar", group_id: 4 }  returns "name='foo''bar' and group_id='4'"
      #   "name='foo''bar' and group_id='4'" returns "name='foo''bar' and group_id='4'"
      def sanitize_sql_for_conditions(condition, table_name = self.table_name)
        return nil if condition.blank?

        case condition
        when Array; sanitize_sql_array(condition)
        when Hash;  sanitize_sql_hash_for_conditions(condition, table_name)
        else        condition
        end
      end
      alias_method :sanitize_sql, :sanitize_sql_for_conditions
      alias_method :sanitize_conditions, :sanitize_sql

      # Accepts an array, hash, or string of SQL conditions and sanitizes
      # them into a valid SQL fragment for a SET clause.
      #   { name: nil, group_id: 4 }  returns "name = NULL , group_id='4'"
      def sanitize_sql_for_assignment(assignments, default_table_name = self.table_name)
        case assignments
        when Array; sanitize_sql_array(assignments)
        when Hash;  sanitize_sql_hash_for_assignment(assignments, default_table_name)
        else        assignments
        end
      end

      # Accepts a hash of SQL conditions and replaces those attributes
      # that correspond to a +composed_of+ relationship with their expanded
      # aggregate attribute values.
      # Given:
      #     class Person < ActiveRecord::Base
      #       composed_of :address, class_name: "Address",
      #         mapping: [%w(address_street street), %w(address_city city)]
      #     end
      # Then:
      #     { address: Address.new("813 abc st.", "chicago") }
      #       # => { address_street: "813 abc st.", address_city: "chicago" }
      def expand_hash_conditions_for_aggregates(attrs)
        expanded_attrs = {}
        attrs.each do |attr, value|
          if aggregation = reflect_on_aggregation(attr.to_sym)
            mapping = aggregation.mapping
            mapping.each do |field_attr, aggregate_attr|
              if mapping.size == 1 && !value.respond_to?(aggregate_attr)
                expanded_attrs[field_attr] = value
              else
                expanded_attrs[field_attr] = value.send(aggregate_attr)
              end
            end
          else
            expanded_attrs[attr] = value
          end
        end
        expanded_attrs
      end

      # Sanitizes a hash of attribute/value pairs into SQL conditions for a WHERE clause.
      #   { name: "foo'bar", group_id: 4 }
      #     # => "name='foo''bar' and group_id= 4"
      #   { status: nil, group_id: [1,2,3] }
      #     # => "status IS NULL and group_id IN (1,2,3)"
      #   { age: 13..18 }
      #     # => "age BETWEEN 13 AND 18"
      #   { 'other_records.id' => 7 }
      #     # => "`other_records`.`id` = 7"
      #   { other_records: { id: 7 } }
      #     # => "`other_records`.`id` = 7"
      # And for value objects on a composed_of relationship:
      #   { address: Address.new("123 abc st.", "chicago") }
      #     # => "address_street='123 abc st.' and address_city='chicago'"
      def sanitize_sql_hash_for_conditions(attrs, default_table_name = self.table_name)
        ActiveSupport::Deprecation.warn(<<-EOWARN)
sanitize_sql_hash_for_conditions is deprecated, and will be removed in Rails 5.0
        EOWARN
        attrs = PredicateBuilder.resolve_column_aliases self, attrs
        attrs = expand_hash_conditions_for_aggregates(attrs)

        table = Arel::Table.new(table_name, arel_engine).alias(default_table_name)
        PredicateBuilder.build_from_hash(self, attrs, table).map { |b|
          connection.visitor.compile b
        }.join(' AND ')
      end
      alias_method :sanitize_sql_hash, :sanitize_sql_hash_for_conditions

      # Sanitizes a hash of attribute/value pairs into SQL conditions for a SET clause.
      #   { status: nil, group_id: 1 }
      #     # => "status = NULL , group_id = 1"
      def sanitize_sql_hash_for_assignment(attrs, table)
        c = connection
        attrs.map do |attr, value|
          "#{c.quote_table_name_for_assignment(table, attr)} = #{quote_bound_value(value, c, columns_hash[attr.to_s])}"
        end.join(', ')
      end

      # Sanitizes a +string+ so that it is safe to use within an SQL
      # LIKE statement. This method uses +escape_character+ to escape all occurrences of "\", "_" and "%"
      def sanitize_sql_like(string, escape_character = "\\")
        pattern = Regexp.union(escape_character, "%", "_")
        string.gsub(pattern) { |x| [escape_character, x].join }
      end

      # Accepts an array of conditions. The array has each value
      # sanitized and interpolated into the SQL statement.
      #   ["name='%s' and group_id='%s'", "foo'bar", 4]  returns  "name='foo''bar' and group_id='4'"
      def sanitize_sql_array(ary)
        statement, *values = ary
        if values.first.is_a?(Hash) && statement =~ /:\w+/
          replace_named_bind_variables(statement, values.first)
        elsif statement.include?('?')
          replace_bind_variables(statement, values)
        elsif statement.blank?
          statement
        else
          statement % values.collect { |value| connection.quote_string(value.to_s) }
        end
      end

      def replace_bind_variables(statement, values) #:nodoc:
        raise_if_bind_arity_mismatch(statement, statement.count('?'), values.size)
        bound = values.dup
        c = connection
        statement.gsub(/\?/) do
          replace_bind_variable(bound.shift, c)
        end
      end

      def replace_bind_variable(value, c = connection) #:nodoc:
        if ActiveRecord::Relation === value
          value.to_sql
        else
          quote_bound_value(value, c)
        end
      end

      def replace_named_bind_variables(statement, bind_vars) #:nodoc:
        statement.gsub(/(:?):([a-zA-Z]\w*)/) do
          if $1 == ':' # skip postgresql casts
            $& # return the whole match
          elsif bind_vars.include?(match = $2.to_sym)
            replace_bind_variable(bind_vars[match])
          else
            raise PreparedStatementInvalid, "missing value for :#{match} in #{statement}"
          end
        end
      end

      def quote_bound_value(value, c = connection, column = nil) #:nodoc:
        if column
          c.quote(value, column)
        elsif value.respond_to?(:map) && !value.acts_like?(:string)
          if value.respond_to?(:empty?) && value.empty?
            c.quote(nil)
          else
            value.map { |v| c.quote(v) }.join(',')
          end
        else
          c.quote(value)
        end
      end

      def raise_if_bind_arity_mismatch(statement, expected, provided) #:nodoc:
        unless expected == provided
          raise PreparedStatementInvalid, "wrong number of bind variables (#{provided} for #{expected}) in: #{statement}"
        end
      end
    end

    # TODO: Deprecate this
    def quoted_id
      self.class.quote_value(id, column_for_attribute(self.class.primary_key))
    end
  end
end
