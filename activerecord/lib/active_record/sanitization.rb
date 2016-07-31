require 'active_support/core_ext/regexp'

module ActiveRecord
  module Sanitization
    extend ActiveSupport::Concern

    module ClassMethods
      protected

      # Accepts an array or string of SQL conditions and sanitizes
      # them into a valid SQL fragment for a WHERE clause.
      #
      #   sanitize_sql_for_conditions(["name=? and group_id=?", "foo'bar", 4])
      #   # => "name='foo''bar' and group_id=4"
      #
      #   sanitize_sql_for_conditions(["name=:name and group_id=:group_id", name: "foo'bar", group_id: 4])
      #   # => "name='foo''bar' and group_id='4'"
      #
      #   sanitize_sql_for_conditions(["name='%s' and group_id='%s'", "foo'bar", 4])
      #   # => "name='foo''bar' and group_id='4'"
      #
      #   sanitize_sql_for_conditions("name='foo''bar' and group_id='4'")
      #   # => "name='foo''bar' and group_id='4'"
      def sanitize_sql_for_conditions(condition)
        return nil if condition.blank?

        case condition
        when Array; sanitize_sql_array(condition)
        else        condition
        end
      end
      alias_method :sanitize_sql, :sanitize_sql_for_conditions
      alias_method :sanitize_conditions, :sanitize_sql

      # Accepts an array, hash, or string of SQL conditions and sanitizes
      # them into a valid SQL fragment for a SET clause.
      #
      #   sanitize_sql_for_assignment(["name=? and group_id=?", nil, 4])
      #   # => "name=NULL and group_id=4"
      #
      #   sanitize_sql_for_assignment(["name=:name and group_id=:group_id", name: nil, group_id: 4])
      #   # => "name=NULL and group_id=4"
      #
      #   Post.send(:sanitize_sql_for_assignment, { name: nil, group_id: 4 })
      #   # => "`posts`.`name` = NULL, `posts`.`group_id` = 4"
      #
      #   sanitize_sql_for_assignment("name=NULL and group_id='4'")
      #   # => "name=NULL and group_id='4'"
      def sanitize_sql_for_assignment(assignments, default_table_name = self.table_name)
        case assignments
        when Array; sanitize_sql_array(assignments)
        when Hash;  sanitize_sql_hash_for_assignment(assignments, default_table_name)
        else        assignments
        end
      end

      # Accepts an array, or string of SQL conditions and sanitizes
      # them into a valid SQL fragment for an ORDER clause.
      #
      #   sanitize_sql_for_order(["field(id, ?)", [1,3,2]])
      #   # => "field(id, 1,3,2)"
      #
      #   sanitize_sql_for_order("id ASC")
      #   # => "id ASC"
      def sanitize_sql_for_order(condition)
        if condition.is_a?(Array) && condition.first.to_s.include?('?')
          sanitize_sql_array(condition)
        else
          condition
        end
      end

      # Accepts a hash of SQL conditions and replaces those attributes
      # that correspond to a {#composed_of}[rdoc-ref:Aggregations::ClassMethods#composed_of]
      # relationship with their expanded aggregate attribute values.
      #
      # Given:
      #
      #   class Person < ActiveRecord::Base
      #     composed_of :address, class_name: "Address",
      #       mapping: [%w(address_street street), %w(address_city city)]
      #   end
      #
      # Then:
      #
      #   { address: Address.new("813 abc st.", "chicago") }
      #   # => { address_street: "813 abc st.", address_city: "chicago" }
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

      # Sanitizes a hash of attribute/value pairs into SQL conditions for a SET clause.
      #
      #   sanitize_sql_hash_for_assignment({ status: nil, group_id: 1 }, "posts")
      #   # => "`posts`.`status` = NULL, `posts`.`group_id` = 1"
      def sanitize_sql_hash_for_assignment(attrs, table)
        c = connection
        attrs.map do |attr, value|
          value = type_for_attribute(attr.to_s).serialize(value)
          "#{c.quote_table_name_for_assignment(table, attr)} = #{c.quote(value)}"
        end.join(', ')
      end

      # Sanitizes a +string+ so that it is safe to use within an SQL
      # LIKE statement. This method uses +escape_character+ to escape all occurrences of "\", "_" and "%".
      #
      #   sanitize_sql_like("100%")
      #   # => "100\\%"
      #
      #   sanitize_sql_like("snake_cased_string")
      #   # => "snake\\_cased\\_string"
      #
      #   sanitize_sql_like("100%", "!")
      #   # => "100!%"
      #
      #   sanitize_sql_like("snake_cased_string", "!")
      #   # => "snake!_cased!_string"
      def sanitize_sql_like(string, escape_character = "\\")
        pattern = Regexp.union(escape_character, "%", "_")
        string.gsub(pattern) { |x| [escape_character, x].join }
      end

      # Accepts an array of conditions. The array has each value
      # sanitized and interpolated into the SQL statement.
      #
      #   sanitize_sql_array(["name=? and group_id=?", "foo'bar", 4])
      #   # => "name='foo''bar' and group_id=4"
      #
      #   sanitize_sql_array(["name=:name and group_id=:group_id", name: "foo'bar", group_id: 4])
      #   # => "name='foo''bar' and group_id=4"
      #
      #   sanitize_sql_array(["name='%s' and group_id='%s'", "foo'bar", 4])
      #   # => "name='foo''bar' and group_id='4'"
      def sanitize_sql_array(ary)
        statement, *values = ary
        if values.first.is_a?(Hash) && /:\w+/.match?(statement)
          replace_named_bind_variables(statement, values.first)
        elsif statement.include?('?')
          replace_bind_variables(statement, values)
        elsif statement.blank?
          statement
        else
          statement % values.collect { |value| connection.quote_string(value.to_s) }
        end
      end

      def replace_bind_variables(statement, values) # :nodoc:
        raise_if_bind_arity_mismatch(statement, statement.count('?'), values.size)
        bound = values.dup
        c = connection
        statement.gsub(/\?/) do
          replace_bind_variable(bound.shift, c)
        end
      end

      def replace_bind_variable(value, c = connection) # :nodoc:
        if ActiveRecord::Relation === value
          value.to_sql
        else
          quote_bound_value(value, c)
        end
      end

      def replace_named_bind_variables(statement, bind_vars) # :nodoc:
        statement.gsub(/(:?):([a-zA-Z]\w*)/) do |match|
          if $1 == ':' # skip postgresql casts
            match # return the whole match
          elsif bind_vars.include?(match = $2.to_sym)
            replace_bind_variable(bind_vars[match])
          else
            raise PreparedStatementInvalid, "missing value for :#{match} in #{statement}"
          end
        end
      end

      def quote_bound_value(value, c = connection) # :nodoc:
        if value.respond_to?(:map) && !value.acts_like?(:string)
          if value.respond_to?(:empty?) && value.empty?
            c.quote(nil)
          else
            value.map { |v| c.quote(v) }.join(',')
          end
        else
          c.quote(value)
        end
      end

      def raise_if_bind_arity_mismatch(statement, expected, provided) # :nodoc:
        unless expected == provided
          raise PreparedStatementInvalid, "wrong number of bind variables (#{provided} for #{expected}) in: #{statement}"
        end
      end
    end

    # TODO: Deprecate this
    def quoted_id # :nodoc:
      self.class.connection.quote(@attributes[self.class.primary_key].value_for_database)
    end
  end
end
