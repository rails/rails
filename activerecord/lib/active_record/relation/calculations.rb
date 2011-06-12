require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'

module ActiveRecord
  module Calculations
    # Count operates using three different approaches.
    #
    # * Count all: By not passing any parameters to count, it will return a count of all the rows for the model.
    # * Count using column: By passing a column name to count, it will return a count of all the
    #   rows for the model with supplied column present.
    # * Count using options will find the row count matched by the options used.
    #
    # The third approach, count using options, accepts an option hash as the only parameter. The options are:
    #
    # * <tt>:conditions</tt>: An SQL fragment like "administrator = 1" or [ "user_name = ?", username ].
    #   See conditions in the intro to ActiveRecord::Base.
    # * <tt>:joins</tt>: Either an SQL fragment for additional joins like "LEFT JOIN comments ON comments.post_id = id"
    #   (rarely needed) or named associations in the same form used for the <tt>:include</tt> option, which will
    #   perform an INNER JOIN on the associated table(s). If the value is a string, then the records
    #   will be returned read-only since they will have attributes that do not correspond to the table's columns.
    #   Pass <tt>:readonly => false</tt> to override.
    # * <tt>:include</tt>: Named associations that should be loaded alongside using LEFT OUTER JOINs.
    #   The symbols named refer to already defined associations. When using named associations, count
    #   returns the number of DISTINCT items for the model you're counting.
    #   See eager loading under Associations.
    # * <tt>:order</tt>: An SQL fragment like "created_at DESC, name" (really only used with GROUP BY calculations).
    # * <tt>:group</tt>: An attribute name by which the result should be grouped. Uses the GROUP BY SQL-clause.
    # * <tt>:select</tt>: By default, this is * as in SELECT * FROM, but can be changed if you, for example,
    #   want to do a join but not include the joined columns.
    # * <tt>:distinct</tt>: Set this to true to make this a distinct calculation, such as
    #   SELECT COUNT(DISTINCT posts.id) ...
    # * <tt>:from</tt> - By default, this is the table name of the class, but can be changed to an
    #   alternate table name (or even the name of a database view).
    #
    # Examples for counting all:
    #   Person.count         # returns the total count of all people
    #
    # Examples for counting by column:
    #   Person.count(:age)  # returns the total count of all people whose age is present in database
    #
    # Examples for count with options:
    #   Person.count(:conditions => "age > 26")
    #
    #   # because of the named association, it finds the DISTINCT count using LEFT OUTER JOIN.
    #   Person.count(:conditions => "age > 26 AND job.salary > 60000", :include => :job)
    #
    #   # finds the number of rows matching the conditions and joins.
    #   Person.count(:conditions => "age > 26 AND job.salary > 60000",
    #                :joins => "LEFT JOIN jobs on jobs.person_id = person.id")
    #
    #   Person.count('id', :conditions => "age > 26") # Performs a COUNT(id)
    #   Person.count(:all, :conditions => "age > 26") # Performs a COUNT(*) (:all is an alias for '*')
    #
    # Note: <tt>Person.count(:all)</tt> will not work because it will use <tt>:all</tt> as the condition.
    # Use Person.count instead.
    def count(column_name = nil, options = {})
      column_name, options = nil, column_name if column_name.is_a?(Hash)
      calculate(:count, column_name, options)
    end

    # Calculates the average value on one or more given columns. Returns +nil+ if there's
    # no row. See +calculate+ for examples with options.
    #
    #   Person.average('age') # => 35.8
    #   Person.average(['age', 'weight']) # => [35.8, 170]
    def average(column_names, options = {})
      calculate(:average, column_names, options)
    end

    # Calculates the minimum value on one or more given columns. The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.minimum('age') # => 7
    #   Person.minimum(['age', 'weight']) # => [7, 100]
    def minimum(column_names, options = {})
      calculate(:minimum, column_names, options)
    end

    # Calculates the maximum value on one or more given columns. The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.maximum('age') # => 93
    #   Person.maximum(['age', 'weight']) # => [93, 210]
    def maximum(column_names, options = {})
      calculate(:maximum, column_names, options)
    end

    # Calculates the sum of values on one or more given columns. The value is returned
    # with the same data type of the column, 0 if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.sum('age') # => 4562
    #   Person.sum(['age', 'weight']) # => [4562, 16721]
    def sum(column_names, options = {})
      calculate(:sum, column_names, options)
    end

    # This calculates aggregate values in one or more given columns. Methods for count, sum, average,
    # minimum, and maximum have been added as shortcuts. Options such as <tt>:conditions</tt>,
    # <tt>:order</tt>, <tt>:group</tt>, <tt>:having</tt>, and <tt>:joins</tt> can be passed to customize the query.
    #
    # There are two basic forms of output:
    #   * Single aggregate value: The single value is type cast to Fixnum for COUNT, Float
    #     for AVG, and the given column's type for everything else.
    #   * Grouped values: This returns an ordered hash of the values and groups them by the
    #     <tt>:group</tt> option. It takes either a column name, or the name of a belongs_to association.
    #
    #       values = Person.maximum(:age, :group => 'last_name')
    #       puts values["Drake"]
    #       => 43
    #
    #       drake  = Family.find_by_last_name('Drake')
    #       values = Person.maximum(:age, :group => :family) # Person belongs_to :family
    #       puts values[drake]
    #       => 43
    #
    #       values.each do |family, max_age|
    #       ...
    #       end
    #
    # Options:
    # * <tt>:conditions</tt> - An SQL fragment like "administrator = 1" or [ "user_name = ?", username ].
    #   See conditions in the intro to ActiveRecord::Base.
    # * <tt>:include</tt>: Eager loading, see Associations for details. Since calculations don't load anything,
    #   the purpose of this is to access fields on joined tables in your conditions, order, or group clauses.
    # * <tt>:joins</tt> - An SQL fragment for additional joins like "LEFT JOIN comments ON comments.post_id = id".
    #   (Rarely needed).
    #   The records will be returned read-only since they will have attributes that do not correspond to the
    #   table's columns.
    # * <tt>:order</tt> - An SQL fragment like "created_at DESC, name" (really only used with GROUP BY calculations).
    # * <tt>:group</tt> - An attribute name by which the result should be grouped. Uses the GROUP BY SQL-clause.
    # * <tt>:select</tt> - By default, this is * as in SELECT * FROM, but can be changed if you for example
    #   want to do a join, but not include the joined columns.
    # * <tt>:distinct</tt> - Set this to true to make this a distinct calculation, such as
    #   SELECT COUNT(DISTINCT posts.id) ...
    #
    # Examples:
    #   Person.calculate(:count, :all) # The same as Person.count
    #   Person.average(:age) # SELECT AVG(age) FROM people...
    #   Person.minimum(:age, :conditions => ['last_name != ?', 'Drake']) # Selects the minimum age for
    #                                                                    # everyone with a last name other than 'Drake'
    #
    #   # Selects the minimum age for any family without any minors
    #   Person.minimum(:age, :having => 'min(age) > 17', :group => :last_name)
    #
    #   Person.sum("2 * age")
    #
    #   # Using multiple columns or aggregate functions
    #   Person.calculate(:average, [:age, :weight]) # SELECT AVG(age), AVG(weight) FROM people
    #   Person.calculate([:average, :sum], :age) # SELECT AVG(age), SUM(age) FROM people
    #   Person.calculate([:average, :sum], [:age, :weight]) # SELECT AVG(age), SUM(weight) FROM people
    def calculate(operations, column_names, options = {})
      operations, column_names = normalize_column_names_and_options(operations, column_names)
      if options.except(:distinct).present?
        apply_finder_options(options.except(:distinct)).calculate(operations, column_names, :distinct => options[:distinct])
      else
        if eager_loading? || (includes_values.present? && references_eager_loaded_tables?)
          construct_relation_for_association_calculations.calculate(operations, column_names, options)
        else
          perform_calculation(operations, column_names, options)
        end
      end
    rescue ThrowResult
      0
    end

    private

    def normalize_column_names_and_options(operations, column_names)
      operations, column_names = [*operations], [*column_names]
      li = [operations.length, column_names.length].max - 1

      if li > 0
        for i in 0..li do
          operations << operations.last  if operations[i].nil?
          column_names << column_names.last if column_names[i].nil?
        end
      end

      operations.map! { |o| o.to_s.downcase }
      [operations, column_names]
    end

    def perform_calculation(operations, column_names, options = {})

      distinct = options[:distinct]

      operations.each_with_index do |op, i|
        if op == "count"
          column_names[i] ||= (select_for_count || :all)

          unless arel.ast.grep(Arel::Nodes::OuterJoin).empty?
            distinct = true
          end

          column_names[i] = primary_key if column_names[i] == :all && distinct

          distinct = nil if column_names[i] =~ /\s*DISTINCT\s+/i
        end
      end

      if @group_values.any?
        execute_grouped_calculation(operations, column_names, distinct)
      else
        execute_simple_calculation(operations, column_names, distinct)
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

    def execute_simple_calculation(operations, column_names, distinct) #:nodoc:
      # Postgresql doesn't like ORDER BY when there are no GROUP BY
      relation = with_default_scope.reorder(nil)
      values = []

      if relation.limit_value || relation.offset_value
        if relation.limit_value == 0
          # Shortcut when limit is zero
          null_values = {"count" => 0,
                         "sum" => 0,
                         "average" => nil,
                         "minimum" => nil,
                         "maximum" => nil}

          operations.each_with_index { |op, i| values << type_cast_calculated_value(null_values[operations[i]], column_for(column_names[i]), operations[i]) }
          return values.length == 1 ? values[0] : values
        else
          query_builder = build_aggregate_subquery(relation, operations, column_names, distinct)
        end

      else
          columns = column_names.map { |c| aggregate_column(c) }

          select_values = []
          operations.each_with_index { |op, i| select_values << operation_over_aggregate_column(columns[i], op, distinct) }

          relation.select_values = select_values

          query_builder = relation.arel
      end
      row = @klass.connection.select_row(query_builder.to_sql)
      row.each_with_index { |value, i| values << type_cast_calculated_value(value, column_for(column_names[i]), operations[i]) }
      values.length == 1 ? values[0] : values
    end

    def execute_grouped_calculation(operations, column_names, distinct) #:nodoc:
      group_attr      = @group_values
      association     = @klass.reflect_on_association(group_attr.first.to_sym)
      associated      = group_attr.size == 1 && association && association.macro == :belongs_to # only count belongs_to associations
      group_fields  = Array(associated ? association.foreign_key : group_attr)
      group_aliases = group_fields.map { |field| column_alias_for(field) }
      group_columns = group_aliases.zip(group_fields).map { |aliaz,field|
        [aliaz, column_for(field)]
      }

      group = @klass.connection.adapter_name == 'FrontBase' ? group_aliases : group_fields

      select_values = []
      aggregate_aliases = []
      operations.each_with_index do |op, i|
        if op == 'count' && column_names[i] == :all
          aggregate_aliases << 'count_all'
        else
          aggregate_aliases << column_alias_for(op, column_names[i])
        end

        select_values << operation_over_aggregate_column(
            aggregate_column(column_names[i]), op, distinct).as(aggregate_aliases[i])
      end

      select_values.concat group_fields.zip(group_aliases).map { |field,aliaz|
        "#{field} AS #{aliaz}"
      }

      relation = with_default_scope.except(:group).group(group.join(','))
      relation.select_values = select_values

      calculated_data = @klass.connection.select_all(relation.to_sql)

      if association
        key_ids     = calculated_data.collect { |row| row[group_aliases.first] }
        key_records = association.klass.base_class.find(key_ids)
        key_records = Hash[key_records.map { |r| [r.id, r] }]
      end

      ActiveSupport::OrderedHash[calculated_data.map do |row|
        key   = group_columns.map { |aliaz, column|
          type_cast_calculated_value(row[aliaz], column)
        }
        key = key.first if key.size == 1
        key = key_records[key] if associated
        values = []
        aggregate_aliases.each_with_index { |aa, i| values << type_cast_calculated_value(row[aa], column_for(column_names[i]), operations[i]) }
        [key, values.length == 1 ? values.first : values]
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
        when 'count'   then value.to_i
        when 'sum'     then type_cast_using_column(value || '0', column)
        when 'average' then value.respond_to?(:to_d) ? value.to_d : value
        else type_cast_using_column(value, column)
      end
    end

    def type_cast_using_column(value, column)
      column ? column.type_cast(value) : value
    end

    def select_for_count
      if @select_values.present?
        select = @select_values.join(", ")
        select if select !~ /(,|\*)/
      end
    end

    def build_aggregate_subquery(relation, operations, column_names, distinct)
      subquery_alias = Arel.sql('subquery_for_aggregate')

      aliased_columns = []
      select_values = []
      column_names.each_with_index do |c, i|
        column_alias = Arel.sql("#{operations[i]}_#{c}_column")
        aliased_columns << aggregate_column(c == :all ? 1 : c).as(column_alias)
        select_values << operation_over_aggregate_column(column_alias, operations[i], distinct)
      end

      relation.select_values = aliased_columns
      subquery = relation.arel.as(subquery_alias)

      sm = Arel::SelectManager.new relation.engine
      sm.project(select_values).from(subquery)
    end
  end
end
