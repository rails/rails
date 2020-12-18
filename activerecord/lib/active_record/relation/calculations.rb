# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveRecord
  module Calculations
    # Count the records.
    #
    #   Person.count
    #   # => the total count of all people
    #
    #   Person.count(:age)
    #   # => returns the total count of all people whose age is present in database
    #
    #   Person.count(:all)
    #   # => performs a COUNT(*) (:all is an alias for '*')
    #
    #   Person.distinct.count(:age)
    #   # => counts the number of different age values
    #
    # If #count is used with {Relation#group}[rdoc-ref:QueryMethods#group],
    # it returns a Hash whose keys represent the aggregated column,
    # and the values are the respective amounts:
    #
    #   Person.group(:city).count
    #   # => { 'Rome' => 5, 'Paris' => 3 }
    #
    # If #count is used with {Relation#group}[rdoc-ref:QueryMethods#group] for multiple columns, it returns a Hash whose
    # keys are an array containing the individual values of each column and the value
    # of each key would be the #count.
    #
    #   Article.group(:status, :category).count
    #   # =>  {["draft", "business"]=>10, ["draft", "technology"]=>4,
    #          ["published", "business"]=>0, ["published", "technology"]=>2}
    #
    # If #count is used with {Relation#select}[rdoc-ref:QueryMethods#select], it will count the selected columns:
    #
    #   Person.select(:age).count
    #   # => counts the number of different age values
    #
    # Note: not all valid {Relation#select}[rdoc-ref:QueryMethods#select] expressions are valid #count expressions. The specifics differ
    # between databases. In invalid cases, an error from the database is thrown.
    def count(column_name = nil)
      if block_given?
        unless column_name.nil?
          raise ArgumentError, "Column name argument is not supported when a block is passed."
        end

        super()
      else
        calculate(:count, column_name)
      end
    end

    # Calculates the average value on a given column. Returns +nil+ if there's
    # no row. See #calculate for examples with options.
    #
    #   Person.average(:age) # => 35.8
    def average(column_name)
      calculate(:average, column_name)
    end

    # Calculates the minimum value on a given column. The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # #calculate for examples with options.
    #
    #   Person.minimum(:age) # => 7
    def minimum(column_name)
      calculate(:minimum, column_name)
    end

    # Calculates the maximum value on a given column. The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # #calculate for examples with options.
    #
    #   Person.maximum(:age) # => 93
    def maximum(column_name)
      calculate(:maximum, column_name)
    end

    # Calculates the sum of values on a given column. The value is returned
    # with the same data type of the column, +0+ if there's no row. See
    # #calculate for examples with options.
    #
    #   Person.sum(:age) # => 4562
    def sum(column_name = nil)
      if block_given?
        unless column_name.nil?
          raise ArgumentError, "Column name argument is not supported when a block is passed."
        end

        super()
      else
        calculate(:sum, column_name)
      end
    end

    # This calculates aggregate values in the given column. Methods for #count, #sum, #average,
    # #minimum, and #maximum have been added as shortcuts.
    #
    #   Person.calculate(:count, :all) # The same as Person.count
    #   Person.average(:age) # SELECT AVG(age) FROM people...
    #
    #   # Selects the minimum age for any family without any minors
    #   Person.group(:last_name).having("min(age) > 17").minimum(:age)
    #
    #   Person.sum("2 * age")
    #
    # There are two basic forms of output:
    #
    # * Single aggregate value: The single value is type cast to Integer for COUNT, Float
    #   for AVG, and the given column's type for everything else.
    #
    # * Grouped values: This returns an ordered hash of the values and groups them. It
    #   takes either a column name, or the name of a belongs_to association.
    #
    #      values = Person.group('last_name').maximum(:age)
    #      puts values["Drake"]
    #      # => 43
    #
    #      drake  = Family.find_by(last_name: 'Drake')
    #      values = Person.group(:family).maximum(:age) # Person belongs_to :family
    #      puts values[drake]
    #      # => 43
    #
    #      values.each do |family, max_age|
    #        ...
    #      end
    def calculate(operation, column_name)
      if has_include?(column_name)
        relation = apply_join_dependency

        if operation.to_s.downcase == "count"
          unless distinct_value || distinct_select?(column_name || select_for_count)
            relation.distinct!
            relation.select_values = [ klass.primary_key || table[Arel.star] ]
          end
          # PostgreSQL: ORDER BY expressions must appear in SELECT list when using DISTINCT
          relation.order_values = [] if group_values.empty?
        end

        relation.calculate(operation, column_name)
      else
        perform_calculation(operation, column_name)
      end
    end

    # Use #pluck as a shortcut to select one or more attributes without
    # loading a bunch of records just to grab the attributes you want.
    #
    #   Person.pluck(:name)
    #
    # instead of
    #
    #   Person.all.map(&:name)
    #
    # Pluck returns an Array of attribute values type-casted to match
    # the plucked column names, if they can be deduced. Plucking an SQL fragment
    # returns String values by default.
    #
    #   Person.pluck(:name)
    #   # SELECT people.name FROM people
    #   # => ['David', 'Jeremy', 'Jose']
    #
    #   Person.pluck(:id, :name)
    #   # SELECT people.id, people.name FROM people
    #   # => [[1, 'David'], [2, 'Jeremy'], [3, 'Jose']]
    #
    #   Person.distinct.pluck(:role)
    #   # SELECT DISTINCT role FROM people
    #   # => ['admin', 'member', 'guest']
    #
    #   Person.where(age: 21).limit(5).pluck(:id)
    #   # SELECT people.id FROM people WHERE people.age = 21 LIMIT 5
    #   # => [2, 3]
    #
    #   Person.pluck(Arel.sql('DATEDIFF(updated_at, created_at)'))
    #   # SELECT DATEDIFF(updated_at, created_at) FROM people
    #   # => ['0', '27761', '173']
    #
    # See also #ids.
    #
    def pluck(*column_names)
      if loaded? && all_attributes?(column_names)
        return records.pluck(*column_names)
      end

      if has_include?(column_names.first)
        relation = apply_join_dependency
        relation.pluck(*column_names)
      else
        klass.disallow_raw_sql!(column_names)
        columns = arel_columns(column_names)
        relation = spawn
        relation.select_values = columns
        result = skip_query_cache_if_necessary do
          if where_clause.contradiction?
            ActiveRecord::Result.new([], [])
          else
            klass.connection.select_all(relation.arel, nil)
          end
        end
        type_cast_pluck_values(result, columns)
      end
    end

    # Pick the value(s) from the named column(s) in the current relation.
    # This is short-hand for <tt>relation.limit(1).pluck(*column_names).first</tt>, and is primarily useful
    # when you have a relation that's already narrowed down to a single row.
    #
    # Just like #pluck, #pick will only load the actual value, not the entire record object, so it's also
    # more efficient. The value is, again like with pluck, typecast by the column type.
    #
    #   Person.where(id: 1).pick(:name)
    #   # SELECT people.name FROM people WHERE id = 1 LIMIT 1
    #   # => 'David'
    #
    #   Person.where(id: 1).pick(:name, :email_address)
    #   # SELECT people.name, people.email_address FROM people WHERE id = 1 LIMIT 1
    #   # => [ 'David', 'david@loudthinking.com' ]
    def pick(*column_names)
      if loaded? && all_attributes?(column_names)
        return records.pick(*column_names)
      end

      limit(1).pluck(*column_names).first
    end

    # Pluck all the ID's for the relation using the table's primary key
    #
    #   Person.ids # SELECT people.id FROM people
    #   Person.joins(:companies).ids # SELECT people.id FROM people INNER JOIN companies ON companies.person_id = people.id
    def ids
      pluck primary_key
    end

    private
      def all_attributes?(column_names)
        (column_names.map(&:to_s) - @klass.attribute_names - @klass.attribute_aliases.keys).empty?
      end

      def has_include?(column_name)
        eager_loading? || (includes_values.present? && column_name && column_name != :all)
      end

      def perform_calculation(operation, column_name)
        operation = operation.to_s.downcase

        # If #count is used with #distinct (i.e. `relation.distinct.count`) it is
        # considered distinct.
        distinct = distinct_value

        if operation == "count"
          column_name ||= select_for_count
          if column_name == :all
            if !distinct
              distinct = distinct_select?(select_for_count) if group_values.empty?
            elsif group_values.any? || select_values.empty? && order_values.empty?
              column_name = primary_key
            end
          elsif distinct_select?(column_name)
            distinct = nil
          end
        end

        if group_values.any?
          execute_grouped_calculation(operation, column_name, distinct)
        else
          execute_simple_calculation(operation, column_name, distinct)
        end
      end

      def distinct_select?(column_name)
        column_name.is_a?(::String) && /\bDISTINCT[\s(]/i.match?(column_name)
      end

      def aggregate_column(column_name)
        return column_name if Arel::Expressions === column_name

        arel_column(column_name.to_s) do |name|
          Arel.sql(column_name == :all ? "*" : name)
        end
      end

      def operation_over_aggregate_column(column, operation, distinct)
        operation == "count" ? column.count(distinct) : column.public_send(operation)
      end

      def execute_simple_calculation(operation, column_name, distinct) #:nodoc:
        if operation == "count" && (column_name == :all && distinct || has_limit_or_offset?)
          # Shortcut when limit is zero.
          return 0 if limit_value == 0

          query_builder = build_count_subquery(spawn, column_name, distinct)
        else
          # PostgreSQL doesn't like ORDER BY when there are no GROUP BY
          relation = unscope(:order).distinct!(false)

          column = aggregate_column(column_name)
          select_value = operation_over_aggregate_column(column, operation, distinct)
          select_value.distinct = true if operation == "sum" && distinct

          relation.select_values = [select_value]

          query_builder = relation.arel
        end

        result = skip_query_cache_if_necessary { @klass.connection.select_all(query_builder) }

        type_cast_calculated_value(result.cast_values.first, operation) do |value|
          type = column.try(:type_caster) ||
            lookup_cast_type_from_join_dependencies(column_name.to_s) || Type.default_value
          type.deserialize(value)
        end
      end

      def execute_grouped_calculation(operation, column_name, distinct) #:nodoc:
        group_fields = group_values
        group_fields = group_fields.uniq if group_fields.size > 1

        unless group_fields == group_values
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            `#{operation}` with group by duplicated fields does no longer affect to result in Rails 6.2.
            To migrate to Rails 6.2's behavior, use `uniq!(:group)` to deduplicate group fields
            (`#{klass.name&.tableize || klass.table_name}.uniq!(:group).#{operation}(#{column_name.inspect})`).
          MSG
          group_fields = group_values
        end

        if group_fields.size == 1 && group_fields.first.respond_to?(:to_sym)
          association  = klass._reflect_on_association(group_fields.first)
          associated   = association && association.belongs_to? # only count belongs_to associations
          group_fields = Array(association.foreign_key) if associated
        end
        group_fields = arel_columns(group_fields)

        group_aliases = group_fields.map { |field|
          field = connection.visitor.compile(field) if Arel.arel_node?(field)
          column_alias_for(field.to_s.downcase)
        }
        group_columns = group_aliases.zip(group_fields)

        column = aggregate_column(column_name)
        column_alias = column_alias_for("#{operation} #{column_name.to_s.downcase}")
        select_value = operation_over_aggregate_column(column, operation, distinct)
        select_value.as(column_alias)

        select_values = [select_value]
        select_values += self.select_values unless having_clause.empty?

        select_values.concat group_columns.map { |aliaz, field|
          if field.respond_to?(:as)
            field.as(aliaz)
          else
            "#{field} AS #{aliaz}"
          end
        }

        relation = except(:group).distinct!(false)
        relation.group_values  = group_fields
        relation.select_values = select_values

        calculated_data = skip_query_cache_if_necessary { @klass.connection.select_all(relation.arel, nil) }

        if association
          key_ids     = calculated_data.collect { |row| row[group_aliases.first] }
          key_records = association.klass.base_class.where(association.klass.base_class.primary_key => key_ids)
          key_records = key_records.index_by(&:id)
        end

        key_types = group_columns.each_with_object({}) do |(aliaz, col_name), types|
          types[aliaz] = type_for(col_name) do
            calculated_data.column_types.fetch(aliaz, Type.default_value)
          end
        end

        hash_rows = calculated_data.cast_values(key_types).map! do |row|
          calculated_data.columns.each_with_object({}).with_index do |(col_name, hash), i|
            hash[col_name] = row[i]
          end
        end

        type = nil
        hash_rows.each_with_object({}) do |row, result|
          key = group_aliases.map { |aliaz| row[aliaz] }
          key = key.first if key.size == 1
          key = key_records[key] if associated

          result[key] = type_cast_calculated_value(row[column_alias], operation) do |value|
            type ||= column.try(:type_caster) ||
              lookup_cast_type_from_join_dependencies(column_name.to_s) || Type.default_value
            type.deserialize(value)
          end
        end
      end

      # Converts the given field to the value that the database adapter returns as
      # a usable column name:
      #
      #   column_alias_for("users.id")                 # => "users_id"
      #   column_alias_for("sum(id)")                  # => "sum_id"
      #   column_alias_for("count(distinct users.id)") # => "count_distinct_users_id"
      #   column_alias_for("count(*)")                 # => "count_all"
      def column_alias_for(field)
        column_alias = +field
        column_alias.gsub!(/\*/, "all")
        column_alias.gsub!(/\W+/, " ")
        column_alias.strip!
        column_alias.gsub!(/ +/, "_")

        connection.table_alias_for(column_alias)
      end

      def type_for(field, &block)
        field_name = field.respond_to?(:name) ? field.name.to_s : field.to_s.split(".").last
        @klass.type_for_attribute(field_name, &block)
      end

      def lookup_cast_type_from_join_dependencies(name, join_dependencies = build_join_dependencies)
        each_join_dependencies(join_dependencies) do |join|
          type = join.base_klass.attribute_types.fetch(name, nil)
          return type if type
        end
        nil
      end

      def type_cast_pluck_values(result, columns)
        cast_types = if result.columns.size != columns.size
          klass.attribute_types
        else
          join_dependencies = nil
          columns.map.with_index do |column, i|
            column.try(:type_caster) ||
              klass.attribute_types.fetch(name = result.columns[i]) do
                join_dependencies ||= build_join_dependencies
                lookup_cast_type_from_join_dependencies(name, join_dependencies) ||
                  result.column_types[name] || Type.default_value
              end
          end
        end
        result.cast_values(cast_types)
      end

      def type_cast_calculated_value(value, operation)
        case operation
        when "count"
          value.to_i
        when "sum"
          yield value || 0
        when "average"
          value&.respond_to?(:to_d) ? value.to_d : value
        else # "minimum", "maximum"
          yield value
        end
      end

      def select_for_count
        if select_values.present?
          return select_values.first if select_values.one?
          select_values.join(", ")
        else
          :all
        end
      end

      def build_count_subquery(relation, column_name, distinct)
        if column_name == :all
          column_alias = Arel.star
          relation.select_values = [ Arel.sql(FinderMethods::ONE_AS_ONE) ] unless distinct
        else
          column_alias = Arel.sql("count_column")
          relation.select_values = [ aggregate_column(column_name).as(column_alias) ]
        end

        subquery_alias = Arel.sql("subquery_for_count")
        select_value = operation_over_aggregate_column(column_alias, "count", false)

        relation.build_subquery(subquery_alias, select_value)
      end
  end
end
