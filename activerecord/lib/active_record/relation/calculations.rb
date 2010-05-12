require 'active_support/core_ext/object/blank'

module ActiveRecord
  module Calculations
    # Count operates using three different approaches.
    #
    # * Count all: By not passing any parameters to count, it will return a count of all the rows for the model.
    # * Count using column: By passing a column name to count, it will return a count of all the rows for the model with supplied column present
    # * Count using options will find the row count matched by the options used.
    #
    # The third approach, count using options, accepts an option hash as the only parameter. The options are:
    #
    # * <tt>:conditions</tt>: An SQL fragment like "administrator = 1" or [ "user_name = ?", username ]. See conditions in the intro to ActiveRecord::Base.
    # * <tt>:joins</tt>: Either an SQL fragment for additional joins like "LEFT JOIN comments ON comments.post_id = id" (rarely needed)
    #   or named associations in the same form used for the <tt>:include</tt> option, which will perform an INNER JOIN on the associated table(s).
    #   If the value is a string, then the records will be returned read-only since they will have attributes that do not correspond to the table's columns.
    #   Pass <tt>:readonly => false</tt> to override.
    # * <tt>:include</tt>: Named associations that should be loaded alongside using LEFT OUTER JOINs. The symbols named refer
    #   to already defined associations. When using named associations, count returns the number of DISTINCT items for the model you're counting.
    #   See eager loading under Associations.
    # * <tt>:order</tt>: An SQL fragment like "created_at DESC, name" (really only used with GROUP BY calculations).
    # * <tt>:group</tt>: An attribute name by which the result should be grouped. Uses the GROUP BY SQL-clause.
    # * <tt>:select</tt>: By default, this is * as in SELECT * FROM, but can be changed if you, for example, want to do a join but not
    #   include the joined columns.
    # * <tt>:distinct</tt>: Set this to true to make this a distinct calculation, such as SELECT COUNT(DISTINCT posts.id) ...
    # * <tt>:from</tt> - By default, this is the table name of the class, but can be changed to an alternate table name (or even the name
    #   of a database view).
    #
    # Examples for counting all:
    #   Person.count         # returns the total count of all people
    #
    # Examples for counting by column:
    #   Person.count(:age)  # returns the total count of all people whose age is present in database
    #
    # Examples for count with options:
    #   Person.count(:conditions => "age > 26")
    #   Person.count(:conditions => "age > 26 AND job.salary > 60000", :include => :job) # because of the named association, it finds the DISTINCT count using LEFT OUTER JOIN.
    #   Person.count(:conditions => "age > 26 AND job.salary > 60000", :joins => "LEFT JOIN jobs on jobs.person_id = person.id") # finds the number of rows matching the conditions and joins.
    #   Person.count('id', :conditions => "age > 26") # Performs a COUNT(id)
    #   Person.count(:all, :conditions => "age > 26") # Performs a COUNT(*) (:all is an alias for '*')
    #
    # Note: <tt>Person.count(:all)</tt> will not work because it will use <tt>:all</tt> as the condition.  Use Person.count instead.
    def count(column_name = nil, options = {})
      column_name, options = nil, column_name if column_name.is_a?(Hash)
      calculate(:count, column_name, options)
    end

    # Calculates the average value on a given column. Returns +nil+ if there's
    # no row. See +calculate+ for examples with options.
    #
    #   Person.average('age') # => 35.8
    def average(column_name, options = {})
      calculate(:average, column_name, options)
    end

    # Calculates the minimum value on a given column.  The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.minimum('age') # => 7
    def minimum(column_name, options = {})
      calculate(:minimum, column_name, options)
    end

    # Calculates the maximum value on a given column. The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.maximum('age') # => 93
    def maximum(column_name, options = {})
      calculate(:maximum, column_name, options)
    end

    # Calculates the sum of values on a given column. The value is returned
    # with the same data type of the column, 0 if there's no row. See
    # +calculate+ for examples with options.
    #
    #   Person.sum('age') # => 4562
    def sum(column_name, options = {})
      calculate(:sum, column_name, options)
    end

    # This calculates aggregate values in the given column.  Methods for count, sum, average, minimum, and maximum have been added as shortcuts.
    # Options such as <tt>:conditions</tt>, <tt>:order</tt>, <tt>:group</tt>, <tt>:having</tt>, and <tt>:joins</tt> can be passed to customize the query.
    #
    # There are two basic forms of output:
    #   * Single aggregate value: The single value is type cast to Fixnum for COUNT, Float for AVG, and the given column's type for everything else.
    #   * Grouped values: This returns an ordered hash of the values and groups them by the <tt>:group</tt> option.  It takes either a column name, or the name
    #     of a belongs_to association.
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
    # * <tt>:conditions</tt> - An SQL fragment like "administrator = 1" or [ "user_name = ?", username ]. See conditions in the intro to ActiveRecord::Base.
    # * <tt>:include</tt>: Eager loading, see Associations for details.  Since calculations don't load anything, the purpose of this is to access fields on joined tables in your conditions, order, or group clauses.
    # * <tt>:joins</tt> - An SQL fragment for additional joins like "LEFT JOIN comments ON comments.post_id = id". (Rarely needed).
    #   The records will be returned read-only since they will have attributes that do not correspond to the table's columns.
    # * <tt>:order</tt> - An SQL fragment like "created_at DESC, name" (really only used with GROUP BY calculations).
    # * <tt>:group</tt> - An attribute name by which the result should be grouped. Uses the GROUP BY SQL-clause.
    # * <tt>:select</tt> - By default, this is * as in SELECT * FROM, but can be changed if you for example want to do a join, but not
    #   include the joined columns.
    # * <tt>:distinct</tt> - Set this to true to make this a distinct calculation, such as SELECT COUNT(DISTINCT posts.id) ...
    #
    # Examples:
    #   Person.calculate(:count, :all) # The same as Person.count
    #   Person.average(:age) # SELECT AVG(age) FROM people...
    #   Person.minimum(:age, :conditions => ['last_name != ?', 'Drake']) # Selects the minimum age for everyone with a last name other than 'Drake'
    #   Person.minimum(:age, :having => 'min(age) > 17', :group => :last_name) # Selects the minimum age for any family without any minors
    #   Person.sum("2 * age")
    def calculate(operation, column_name, options = {})
      if options.except(:distinct).present?
        apply_finder_options(options.except(:distinct)).calculate(operation, column_name, :distinct => options[:distinct])
      else
        if eager_loading? || includes_values.present?
          construct_relation_for_association_calculations.calculate(operation, column_name, options)
        else
          perform_calculation(operation, column_name, options)
        end
      end
    rescue ThrowResult
      0
    end

    private

    def perform_calculation(operation, column_name, options = {})
      operation = operation.to_s.downcase

      if operation == "count"
        column_name ||= (select_for_count || :all)

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
    end

    def execute_simple_calculation(operation, column_name, distinct) #:nodoc:
      column = if @klass.column_names.include?(column_name.to_s)
        Arel::Attribute.new(@klass.unscoped, column_name)
      else
        Arel::SqlLiteral.new(column_name == :all ? "*" : column_name.to_s)
      end

      # Postgresql doesn't like ORDER BY when there are no GROUP BY
      relation = except(:order).select(operation == 'count' ? column.count(distinct) : column.send(operation))
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

      relation = except(:group).select(select_statement).group(group)

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
      if value.is_a?(String) || value.nil?
        case operation
          when 'count'   then value.to_i
          when 'sum'     then type_cast_using_column(value || '0', column)
          when 'average' then value.try(:to_d)
          else type_cast_using_column(value, column)
        end
      else
        value
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
  end
end
