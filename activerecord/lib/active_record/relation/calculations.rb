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
    # If +count+ is used with +group+, it returns a Hash whose keys represent the aggregated column,
    # and the values are the respective amounts:
    #
    #   Person.group(:city).count
    #   # => { 'Rome' => 5, 'Paris' => 3 }
    #
    # If +count+ is used with +group+ for multiple columns, it returns a Hash whose
    # keys are an array containing the individual values of each column and the value
    # of each key would be the +count+.
    #
    #   Article.group(:status, :category).count
    #   # =>  {["draft", "business"]=>10, ["draft", "technology"]=>4,
    #          ["published", "business"]=>0, ["published", "technology"]=>2}
    #
    # If +count+ is used with +select+, it will count the selected columns:
    #
    #   Person.select(:age).count
    #   # => counts the number of different age values
    #
    # Note: not all valid +select+ expressions are valid +count+ expressions. The specifics differ
    # between databases. In invalid cases, an error from the database is thrown.
    def count(column_name = nil, options = {})
      # TODO: Remove options argument as soon we remove support to
      # activerecord-deprecated_finders.
      column_name, options = nil, column_name if column_name.is_a?(Hash)
      calculate(:count, column_name, options)
    end

    # Calculates the average value on a given column. Returns +nil+ if there's
    # no row. See +calculate+ for examples with options.
    #
    #   Person.average(:age) # => 35.8
    def average(column_name, options = {})
      # TODO: Remove options argument as soon we remove support to
      # activerecord-deprecated_finders.
      calculate(:average, column_name, options)
    end

    # Calculates the minimum value on a given column. The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.minimum(:age) # => 7
    def minimum(column_name, options = {})
      # TODO: Remove options argument as soon we remove support to
      # activerecord-deprecated_finders.
      calculate(:minimum, column_name, options)
    end

    # Calculates the maximum value on a given column. The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.maximum(:age) # => 93
    def maximum(column_name, options = {})
      # TODO: Remove options argument as soon we remove support to
      # activerecord-deprecated_finders.
      calculate(:maximum, column_name, options)
    end

    # Calculates the sum of values on a given column. The value is returned
    # with the same data type of the column, 0 if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.sum(:age) # => 4562
    def sum(*args)
      calculate(:sum, *args)
    end

    # This calculates aggregate values in the given column. Methods for count, sum, average,
    # minimum, and maximum have been added as shortcuts.
    #
    # There are two basic forms of output:
    #
    #   * Single aggregate value: The single value is type cast to Fixnum for COUNT, Float
    #     for AVG, and the given column's type for everything else.
    #
    #   * Grouped values: This returns an ordered hash of the values and groups them. It
    #     takes either a column name, or the name of a belongs_to association.
    #
    #       values = Person.group('last_name').maximum(:age)
    #       puts values["Drake"]
    #       # => 43
    #
    #       drake  = Family.find_by(last_name: 'Drake')
    #       values = Person.group(:family).maximum(:age) # Person belongs_to :family
    #       puts values[drake]
    #       # => 43
    #
    #       values.each do |family, max_age|
    #       ...
    #       end
    #
    #   Person.calculate(:count, :all) # The same as Person.count
    #   Person.average(:age) # SELECT AVG(age) FROM people...
    #
    #   # Selects the minimum age for any family without any minors
    #   Person.group(:last_name).having("min(age) > 17").minimum(:age)
    #
    #   Person.sum("2 * age")
    def calculate(operation, column_name, options = {})
      # TODO: Remove options argument as soon we remove support to
      # activerecord-deprecated_finders.
      if column_name.is_a?(Symbol) && attribute_alias?(column_name)
        column_name = attribute_alias(column_name)
      end

      if has_include?(column_name)
        construct_relation_for_association_calculations.calculate(operation, column_name, options)
      else
        perform_calculation(operation, column_name, options)
      end
    end

    # Use <tt>pluck</tt> as a shortcut to select one or more attributes without
    # loading a bunch of records just to grab the attributes you want.
    #
    #   Person.pluck(:name)
    #
    # instead of
    #
    #   Person.all.map(&:name)
    #
    # Pluck returns an <tt>Array</tt> of attribute values type-casted to match
    # the plucked column names, if they can be deduced. Plucking an SQL fragment
    # returns String values by default.
    #
    #   Person.pluck(:id)
    #   # SELECT people.id FROM people
    #   # => [1, 2, 3]
    #
    #   Person.pluck(:id, :name)
    #   # SELECT people.id, people.name FROM people
    #   # => [[1, 'David'], [2, 'Jeremy'], [3, 'Jose']]
    #
    #   Person.pluck('DISTINCT role')
    #   # SELECT DISTINCT role FROM people
    #   # => ['admin', 'member', 'guest']
    #
    #   Person.where(age: 21).limit(5).pluck(:id)
    #   # SELECT people.id FROM people WHERE people.age = 21 LIMIT 5
    #   # => [2, 3]
    #
    #   Person.pluck('DATEDIFF(updated_at, created_at)')
    #   # SELECT DATEDIFF(updated_at, created_at) FROM people
    #   # => ['0', '27761', '173']
    #
    def pluck(*column_names)
      column_names.map! do |column_name|
        if column_name.is_a?(Symbol) && attribute_alias?(column_name)
          attribute_alias(column_name)
        else
          column_name.to_s
        end
      end

      if has_include?(column_names.first)
        construct_relation_for_association_calculations.pluck(*column_names)
      else
        relation = spawn
        relation.select_values = column_names.map { |cn|
          columns_hash.key?(cn) ? arel_table[cn] : cn
        }
        result = klass.connection.select_all(relation.arel, nil, relation.arel.bind_values + bind_values)
        result.cast_values(klass.column_types)
      end
    end

    # Pluck all the ID's for the relation using the table's primary key
    #
    #   Person.ids # SELECT people.id FROM people
    #   Person.joins(:companies).ids # SELECT people.id FROM people INNER JOIN companies ON companies.person_id = people.id
    def ids
      pluck primary_key
    end

    private

    def has_include?(column_name)
      eager_loading? || (includes_values.present? && ((column_name && column_name != :all) || references_eager_loaded_tables?))
    end

    def perform_calculation(operation, column_name, options = {})
      # TODO: Remove options argument as soon we remove support to
      # activerecord-deprecated_finders.
      operation = operation.to_s.downcase

      # If #count is used with #distinct / #uniq it is considered distinct. (eg. relation.distinct.count)
      distinct = self.distinct_value

      if operation == "count"
        column_name ||= select_for_count

        unless arel.ast.grep(Arel::Nodes::OuterJoin).empty?
          distinct = true
        end

        column_name = primary_key if column_name == :all && distinct
        distinct = nil if column_name =~ /\s*DISTINCT[\s(]+/i
      end

      if group_values.any?
        execute_grouped_calculation(operation, column_name, distinct)
      else
        execute_simple_calculation(operation, column_name, distinct)
      end
    end

    def aggregate_column(column_name)
      if @klass.column_names.include?(column_name.to_s)
        Arel::Attribute.new(@klass.unscoped.table, column_name)
      else
        Arel.sql(column_name == :all ? "*" : column_name.to_s)
      end
    end

    def operation_over_aggregate_column(column, operation, distinct)
      operation == 'count' ? column.count(distinct) : column.send(operation)
    end

    def execute_simple_calculation(operation, column_name, distinct) #:nodoc:
      # Postgresql doesn't like ORDER BY when there are no GROUP BY
      relation = unscope(:order)

      column_alias = column_name

      bind_values = nil

      if operation == "count" && (relation.limit_value || relation.offset_value)
        # Shortcut when limit is zero.
        return 0 if relation.limit_value == 0

        query_builder = build_count_subquery(relation, column_name, distinct)
        bind_values = query_builder.bind_values + relation.bind_values
      else
        column = aggregate_column(column_name)

        select_value = operation_over_aggregate_column(column, operation, distinct)

        column_alias = select_value.alias
        column_alias ||= @klass.connection.column_name_for_operation(operation, select_value)
        relation.select_values = [select_value]

        query_builder = relation.arel
        bind_values = query_builder.bind_values + relation.bind_values
      end

      result = @klass.connection.select_all(query_builder, nil, bind_values)
      row    = result.first
      value  = row && row.values.first
      column = result.column_types.fetch(column_alias) do
        type_for(column_name)
      end

      type_cast_calculated_value(value, column, operation)
    end

    def execute_grouped_calculation(operation, column_name, distinct) #:nodoc:
      group_attrs = group_values

      if group_attrs.first.respond_to?(:to_sym)
        association  = @klass._reflect_on_association(group_attrs.first)
        associated   = group_attrs.size == 1 && association && association.belongs_to? # only count belongs_to associations
        group_fields = Array(associated ? association.foreign_key : group_attrs)
      else
        group_fields = group_attrs
      end

      group_aliases = group_fields.map { |field|
        column_alias_for(field)
      }
      group_columns = group_aliases.zip(group_fields).map { |aliaz,field|
        [aliaz, field]
      }

      group = group_fields

      if operation == 'count' && column_name == :all
        aggregate_alias = 'count_all'
      else
        aggregate_alias = column_alias_for([operation, column_name].join(' '))
      end

      select_values = [
        operation_over_aggregate_column(
          aggregate_column(column_name),
          operation,
          distinct).as(aggregate_alias)
      ]
      select_values += select_values unless having_values.empty?

      select_values.concat group_fields.zip(group_aliases).map { |field,aliaz|
        if field.respond_to?(:as)
          field.as(aliaz)
        else
          "#{field} AS #{aliaz}"
        end
      }

      relation = except(:group)
      relation.group_values  = group
      relation.select_values = select_values

      calculated_data = @klass.connection.select_all(relation, nil, relation.arel.bind_values + bind_values)

      if association
        key_ids     = calculated_data.collect { |row| row[group_aliases.first] }
        key_records = association.klass.base_class.find(key_ids)
        key_records = Hash[key_records.map { |r| [r.id, r] }]
      end

      Hash[calculated_data.map do |row|
        key = group_columns.map { |aliaz, col_name|
          column = calculated_data.column_types.fetch(aliaz) do
            type_for(col_name)
          end
          type_cast_calculated_value(row[aliaz], column)
        }
        key = key.first if key.size == 1
        key = key_records[key] if associated

        column_type = calculated_data.column_types.fetch(aggregate_alias) { type_for(column_name) }
        [key, type_cast_calculated_value(row[aggregate_alias], column_type, operation)]
      end]
    end

    # Converts the given keys to the value that the database adapter returns as
    # a usable column name:
    #
    #   column_alias_for("users.id")                 # => "users_id"
    #   column_alias_for("sum(id)")                  # => "sum_id"
    #   column_alias_for("count(distinct users.id)") # => "count_distinct_users_id"
    #   column_alias_for("count(*)")                 # => "count_all"
    #   column_alias_for("count", "id")              # => "count_id"
    def column_alias_for(keys)
      if keys.respond_to? :name
        keys = "#{keys.relation.name}.#{keys.name}"
      end

      table_name = keys.to_s.downcase
      table_name.gsub!(/\*/, 'all')
      table_name.gsub!(/\W+/, ' ')
      table_name.strip!
      table_name.gsub!(/ +/, '_')

      @klass.connection.table_alias_for(table_name)
    end

    def type_for(field)
      field_name = field.respond_to?(:name) ? field.name.to_s : field.to_s.split('.').last
      @klass.type_for_attribute(field_name)
    end

    def type_cast_calculated_value(value, type, operation = nil)
      case operation
        when 'count'   then value.to_i
        when 'sum'     then type.type_cast_from_database(value || 0)
        when 'average' then value.respond_to?(:to_d) ? value.to_d : value
        else type.type_cast_from_database(value)
      end
    end

    # TODO: refactor to allow non-string `select_values` (eg. Arel nodes).
    def select_for_count
      if select_values.present?
        select_values.join(", ")
      else
        :all
      end
    end

    def build_count_subquery(relation, column_name, distinct)
      column_alias = Arel.sql('count_column')
      subquery_alias = Arel.sql('subquery_for_count')

      aliased_column = aggregate_column(column_name == :all ? 1 : column_name).as(column_alias)
      relation.select_values = [aliased_column]
      arel = relation.arel
      subquery = arel.as(subquery_alias)

      sm = Arel::SelectManager.new relation.engine
      sm.bind_values = arel.bind_values
      select_value = operation_over_aggregate_column(column_alias, 'count', distinct)
      sm.project(select_value).from(subquery)
    end
  end
end
