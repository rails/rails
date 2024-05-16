# frozen_string_literal: true

module ActiveRecord
  module Sanitization
    extend ActiveSupport::Concern

    module ClassMethods
      # Accepts an array of SQL conditions and sanitizes them into a valid
      # SQL fragment for a WHERE clause.
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
      # This method will NOT sanitize an SQL string since it won't contain
      # any conditions in it and will return the string as is.
      #
      #   sanitize_sql_for_conditions("name='foo''bar' and group_id='4'")
      #   # => "name='foo''bar' and group_id='4'"
      #
      # Note that this sanitization method is not schema-aware, hence won't do any type casting
      # and will directly use the database adapter's +quote+ method.
      # For MySQL specifically this means that numeric parameters will be quoted as strings
      # to prevent query manipulation attacks.
      #
      #   sanitize_sql_for_conditions(["role = ?", 0])
      #   # => "role = '0'"
      def sanitize_sql_for_conditions(condition)
        return nil if condition.blank?

        case condition
        when Array; sanitize_sql_array(condition)
        else        condition
        end
      end
      alias :sanitize_sql :sanitize_sql_for_conditions

      # Accepts an array or hash of SQL conditions and sanitizes them into
      # a valid SQL fragment for a SET clause.
      #
      #   sanitize_sql_for_assignment(["name=? and group_id=?", nil, 4])
      #   # => "name=NULL and group_id=4"
      #
      #   sanitize_sql_for_assignment(["name=:name and group_id=:group_id", name: nil, group_id: 4])
      #   # => "name=NULL and group_id=4"
      #
      #   Post.sanitize_sql_for_assignment({ name: nil, group_id: 4 })
      #   # => "`posts`.`name` = NULL, `posts`.`group_id` = 4"
      #
      # This method will NOT sanitize an SQL string since it won't contain
      # any conditions in it and will return the string as is.
      #
      #   sanitize_sql_for_assignment("name=NULL and group_id='4'")
      #   # => "name=NULL and group_id='4'"
      #
      # Note that this sanitization method is not schema-aware, hence won't do any type casting
      # and will directly use the database adapter's +quote+ method.
      # For MySQL specifically this means that numeric parameters will be quoted as strings
      # to prevent query manipulation attacks.
      #
      #   sanitize_sql_for_assignment(["role = ?", 0])
      #   # => "role = '0'"
      def sanitize_sql_for_assignment(assignments, default_table_name = table_name)
        case assignments
        when Array; sanitize_sql_array(assignments)
        when Hash;  sanitize_sql_hash_for_assignment(assignments, default_table_name)
        else        assignments
        end
      end

      # Accepts an array, or string of SQL conditions and sanitizes
      # them into a valid SQL fragment for an ORDER clause.
      #
      #   sanitize_sql_for_order([Arel.sql("field(id, ?)"), [1,3,2]])
      #   # => "field(id, 1,3,2)"
      #
      #   sanitize_sql_for_order("id ASC")
      #   # => "id ASC"
      def sanitize_sql_for_order(condition)
        if condition.is_a?(Array) && condition.first.to_s.include?("?")
          disallow_raw_sql!(
            [condition.first],
            permit: adapter_class.column_name_with_order_matcher
          )

          # Ensure we aren't dealing with a subclass of String that might
          # override methods we use (e.g. Arel::Nodes::SqlLiteral).
          if condition.first.kind_of?(String) && !condition.first.instance_of?(String)
            condition = [String.new(condition.first), *condition[1..-1]]
          end

          Arel.sql(sanitize_sql_array(condition))
        else
          condition
        end
      end

      # Sanitizes a hash of attribute/value pairs into SQL conditions for a SET clause.
      #
      #   sanitize_sql_hash_for_assignment({ status: nil, group_id: 1 }, "posts")
      #   # => "`posts`.`status` = NULL, `posts`.`group_id` = 1"
      def sanitize_sql_hash_for_assignment(attrs, table)
        c = connection
        attrs.map do |attr, value|
          type = type_for_attribute(attr)
          value = type.serialize(type.cast(value))
          "#{c.quote_table_name_for_assignment(table, attr)} = #{c.quote(value)}"
        end.join(", ")
      end

      # Sanitizes a +string+ so that it is safe to use within an SQL
      # LIKE statement. This method uses +escape_character+ to escape all
      # occurrences of itself, "_" and "%".
      #
      #   sanitize_sql_like("100% true!")
      #   # => "100\\% true!"
      #
      #   sanitize_sql_like("snake_cased_string")
      #   # => "snake\\_cased\\_string"
      #
      #   sanitize_sql_like("100% true!", "!")
      #   # => "100!% true!!"
      #
      #   sanitize_sql_like("snake_cased_string", "!")
      #   # => "snake!_cased!_string"
      def sanitize_sql_like(string, escape_character = "\\")
        if string.include?(escape_character) && escape_character != "%" && escape_character != "_"
          string = string.gsub(escape_character, '\0\0')
        end

        string.gsub(/(?=[%_])/, escape_character)
      end

      # Accepts an array of conditions. The array has each value
      # sanitized and interpolated into the SQL statement. If using named bind
      # variables in SQL statements where a colon is required verbatim use a
      # backslash to escape.
      #
      #   sanitize_sql_array(["name=? and group_id=?", "foo'bar", 4])
      #   # => "name='foo''bar' and group_id=4"
      #
      #   sanitize_sql_array(["name=:name and group_id=:group_id", name: "foo'bar", group_id: 4])
      #   # => "name='foo''bar' and group_id=4"
      #
      #   sanitize_sql_array(["TO_TIMESTAMP(:date, 'YYYY/MM/DD HH12\\:MI\\:SS')", date: "foo"])
      #   # => "TO_TIMESTAMP('foo', 'YYYY/MM/DD HH12:MI:SS')"
      #
      #   sanitize_sql_array(["name='%s' and group_id='%s'", "foo'bar", 4])
      #   # => "name='foo''bar' and group_id='4'"
      #
      # Note that this sanitization method is not schema-aware, hence won't do any type casting
      # and will directly use the database adapter's +quote+ method.
      # For MySQL specifically this means that numeric parameters will be quoted as strings
      # to prevent query manipulation attacks.
      #
      #   sanitize_sql_array(["role = ?", 0])
      #   # => "role = '0'"
      def sanitize_sql_array(ary)
        statement, *values = ary
        if values.first.is_a?(Hash) && /:\w+/.match?(statement)
          with_connection do |c|
            replace_named_bind_variables(c, statement, values.first)
          end
        elsif statement.include?("?")
          with_connection do |c|
            replace_bind_variables(c, statement, values)
          end
        elsif statement.blank?
          statement
        else
          with_connection do |c|
            statement % values.collect { |value| c.quote_string(value.to_s) }
          end
        end
      end

      def disallow_raw_sql!(args, permit: adapter_class.column_name_matcher) # :nodoc:
        unexpected = nil
        args.each do |arg|
          next if arg.is_a?(Symbol) || Arel.arel_node?(arg) || permit.match?(arg.to_s.strip)
          (unexpected ||= []) << arg
        end

        if unexpected
          raise(ActiveRecord::UnknownAttributeReference,
            "Dangerous query method (method whose arguments are used as raw " \
            "SQL) called with non-attribute argument(s): " \
            "#{unexpected.map(&:inspect).join(", ")}." \
            "This method should not be called with user-provided values, such as request " \
            "parameters or model attributes. Known-safe values can be passed " \
            "by wrapping them in Arel.sql()."
          )
        end
      end

      private
        def replace_bind_variables(connection, statement, values)
          raise_if_bind_arity_mismatch(statement, statement.count("?"), values.size)
          bound = values.dup
          statement.gsub(/\?/) do
            replace_bind_variable(connection, bound.shift)
          end
        end

        def replace_bind_variable(connection, value)
          if ActiveRecord::Relation === value
            value.to_sql
          else
            quote_bound_value(connection, value)
          end
        end

        def replace_named_bind_variables(connection, statement, bind_vars)
          statement.gsub(/([:\\]?):([a-zA-Z]\w*)/) do |match|
            if $1 == ":" # skip PostgreSQL casts
              match # return the whole match
            elsif $1 == "\\" # escaped literal colon
              match[1..-1] # return match with escaping backlash char removed
            elsif bind_vars.include?(match = $2.to_sym)
              replace_bind_variable(connection, bind_vars[match])
            else
              raise PreparedStatementInvalid, "missing value for :#{match} in #{statement}"
            end
          end
        end

        def quote_bound_value(connection, value)
          if value.respond_to?(:map) && !value.acts_like?(:string)
            values = value.map { |v| v.respond_to?(:id_for_database) ? v.id_for_database : v }
            if values.empty?
              connection.quote(connection.cast_bound_value(nil))
            else
              values.map! { |v| connection.quote(connection.cast_bound_value(v)) }.join(",")
            end
          else
            value = value.id_for_database if value.respond_to?(:id_for_database)
            connection.quote(connection.cast_bound_value(value))
          end
        end

        def raise_if_bind_arity_mismatch(statement, expected, provided)
          unless expected == provided
            raise PreparedStatementInvalid, "wrong number of bind variables (#{provided} for #{expected}) in: #{statement}"
          end
        end
    end
  end
end
