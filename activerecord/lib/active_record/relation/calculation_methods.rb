module ActiveRecord
  module CalculationMethods

    def count(*args)
      calculate(:count, *construct_count_options_from_args(*args))
    end

    # Calculates the average value on a given column. The value is returned as
    # a float, or +nil+ if there's no row. See +calculate+ for examples with
    # options.
    #
    #   Person.average('age') # => 35.8
    def average(column_name, options = {})
      calculation_relation(options).calculate(:average, column_name)
    end

    # Calculates the minimum value on a given column.  The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.minimum('age') # => 7
    def minimum(column_name, options = {})
      calculation_relation(options).calculate(:minimum, column_name)
    end

    # Calculates the maximum value on a given column. The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.maximum('age') # => 93
    def maximum(column_name, options = {})
      calculation_relation(options).calculate(:maximum, column_name)
    end

    # Calculates the sum of values on a given column. The value is returned
    # with the same data type of the column, 0 if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.sum('age') # => 4562
    def sum(column_name, options = {})
      calculation_relation(options).calculate(:sum, column_name)
    end

    def calculate(operation, column_name, options = {})
      operation = operation.to_s.downcase

      if operation == "count"
        joins = arel.joins(arel)
        if joins.present? && joins =~ /LEFT OUTER/i
          distinct = true
          column_name = @klass.primary_key if column_name == :all
        end

        distinct = nil if column_name.to_s =~ /\s*DISTINCT\s+/i
        distinct ||= options[:distinct]
      else
        distinct = nil
      end

      distinct = options[:distinct] || distinct
      column_name = :all if column_name.blank? && operation == "count"

      if @group_values.any?
        return execute_grouped_calculation(operation, column_name)
      else
        return execute_simple_calculation(operation, column_name, distinct)
      end
    rescue ThrowResult
      0
    end

    def calculation_relation(options = {})
      if options.present?
        apply_finder_options(options.except(:distinct)).calculation_relation
      else
        (eager_loading? || includes_values.present?) ? construct_relation_for_association_calculations : self
      end
    end

    private

    def execute_simple_calculation(operation, column_name, distinct) #:nodoc:
      column = if @klass.column_names.include?(column_name.to_s)
        Arel::Attribute.new(@klass.unscoped, column_name)
      else
        Arel::SqlLiteral.new(column_name == :all ? "*" : column_name.to_s)
      end

      relation = select(operation == 'count' ? column.count(distinct) : column.send(operation))
      type_cast_calculated_value(@klass.connection.select_value(relation.to_sql), column_for(column_name), operation)
    end

    def execute_grouped_calculation(operation, column_name) #:nodoc:
      group_attr      = @group_values.first
      association     = @klass.reflect_on_association(group_attr.to_sym)
      associated      = association && association.macro == :belongs_to # only count belongs_to associations
      group_field     = associated ? association.primary_key_name : group_attr
      group_alias     = column_alias_for(group_field)
      group_column    = column_for(group_field)

      group = @klass.connection.adapter_name == 'FrontBase' ? group_alias : group_field

      aggregate_alias = column_alias_for(operation, column_name)

      select_statement = if operation == 'count' && column_name == :all
        "COUNT(*) AS count_all"
      else
        Arel::Attribute.new(@klass.unscoped, column_name).send(operation).as(aggregate_alias).to_sql
      end

      select_statement <<  ", #{group_field} AS #{group_alias}"

      relation = select(select_statement).group(group)

      calculated_data = @klass.connection.select_all(relation.to_sql)

      if association
        key_ids     = calculated_data.collect { |row| row[group_alias] }
        key_records = association.klass.base_class.find(key_ids)
        key_records = key_records.inject({}) { |hsh, r| hsh.merge(r.id => r) }
      end

      calculated_data.inject(ActiveSupport::OrderedHash.new) do |all, row|
        key   = type_cast_calculated_value(row[group_alias], group_column)
        key   = key_records[key] if associated
        value = row[aggregate_alias]
        all[key] = type_cast_calculated_value(value, column_for(column_name), operation)
        all
      end
    end

    def construct_count_options_from_args(*args)
      options     = {}
      column_name = :all

      # Handles count(), count(:column), count(:distinct => true), count(:column, :distinct => true)
      case args.size
      when 0
        select = get_projection_name_from_chained_relations
        column_name = select if select !~ /(,|\*)/
      when 1
        if args[0].is_a?(Hash)
          select = get_projection_name_from_chained_relations
          column_name = select if select !~ /(,|\*)/
          options = args[0]
        else
          column_name = args[0]
        end
      when 2
        column_name, options = args
      else
        raise ArgumentError, "Unexpected parameters passed to count(): #{args.inspect}"
      end

      [column_name || :all, options]
    end

    # Converts the given keys to the value that the database adapter returns as
    # a usable column name:
    #
    #   column_alias_for("users.id")                 # => "users_id"
    #   column_alias_for("sum(id)")                  # => "sum_id"
    #   column_alias_for("count(distinct users.id)") # => "count_distinct_users_id"
    #   column_alias_for("count(*)")                 # => "count_all"
    #   column_alias_for("count", "id")              # => "count_id"
    def column_alias_for(*keys)
      table_name = keys.join(' ')
      table_name.downcase!
      table_name.gsub!(/\*/, 'all')
      table_name.gsub!(/\W+/, ' ')
      table_name.strip!
      table_name.gsub!(/ +/, '_')

      @klass.connection.table_alias_for(table_name)
    end

    def column_for(field)
      field_name = field.to_s.split('.').last
      @klass.columns.detect { |c| c.name.to_s == field_name }
    end

    def type_cast_calculated_value(value, column, operation = nil)
      case operation
        when 'count' then value.to_i
        when 'sum'   then type_cast_using_column(value || '0', column)
        when 'average'   then value && (value.is_a?(Fixnum) ? value.to_f : value).to_d
        else type_cast_using_column(value, column)
      end
    end

    def type_cast_using_column(value, column)
      column ? column.type_cast(value) : value
    end

    def get_projection_name_from_chained_relations
      @select_values.join(", ") if @select_values.present?
    end

  end
end
