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

    # Calculates the average value on a given column. Returns +nil+ if there's
    # no row. See +calculate+ for examples with options.
    #
    #   Person.average('age') # => 35.8
    def average(column_name, options = {})
      calculate(:average, column_name, options)
    end

    # Calculates the minimum value on a given column. The value is returned
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
    def sum(*args)
      if block_given?
        self.to_a.sum(*args) {|*block_args| yield(*block_args)}
      else
        calculate(:sum, *args)
      end
    end

    # This calculates aggregate values in the given column. Methods for count, sum, average,
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
    def calculate(operation, column_name, options = {})
      if options.except(:distinct).present?
        apply_finder_options(options.except(:distinct)).calculate(operation, column_name, :distinct => options[:distinct])
      else
        relation = with_default_scope

        if relation.equal?(self)
          if eager_loading? || (includes_values.present? && references_eager_loaded_tables?)
            construct_relation_for_association_calculations.calculate(operation, column_name, options)
          else
            perform_calculation(operation, column_name, options)
          end
        else
          relation.calculate(operation, column_name, options)
        end
      end
    rescue ThrowResult
      0
    end

    # This method is designed to perform select by a single column as direct SQL query
    # Returns <tt>Array</tt> with values of the specified column name
    # The values has same data type as column.
    #
    # Examples:
    #
    #   Person.pluck(:id) # SELECT people.id FROM people
    #   Person.uniq.pluck(:role) # SELECT DISTINCT role FROM people
    #   Person.where(:confirmed => true).limit(5).pluck(:id)
    #
    def pluck(column_name)
      if column_name.is_a?(Symbol) && column_names.include?(column_name.to_s)
        column_name = "#{connection.quote_table_name(table_name)}.#{connection.quote_column_name(column_name)}"
      end

      result = klass.connection.exec_query(select(column_name).to_sql)
      last_column = result.columns.last

      result.map do |attributes|
        klass.type_cast_attribute(last_column, klass.initialize_attributes(attributes))
      end
    end

    private

    def perform_calculation(operation, column_name, options = {})
      operation = operation.to_s.downcase

      # If #count is used in conjuction with #uniq it is considered distinct. (eg. relation.uniq.count)
      distinct = options[:distinct] || self.uniq_value

      if operation == "count"
        column_name ||= (select_for_count || :all)

        unless arel.ast.grep(Arel::Nodes::OuterJoin).empty?
          distinct = true
        end

        column_name = primary_key if column_name == :all && distinct

        distinct = nil if column_name =~ /\s*DISTINCT\s+/i
      end

      if @group_values.any?
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
      relation = reorder(nil)

      if operation == "count" && (relation.limit_value || relation.offset_value)
        # Shortcut when limit is zero.
        return 0 if relation.limit_value == 0

        query_builder = build_count_subquery(relation, column_name, distinct)
      else
        column = aggregate_column(column_name)

        select_value = operation_over_aggregate_column(column, operation, distinct)

        relation.select_values = [select_value]

        query_builder = relation.arel
      end

      type_cast_calculated_value(@klass.connection.select_value(query_builder), column_for(column_name), operation)
    end

    def execute_grouped_calculation(operation, column_name, distinct) #:nodoc:
      group_attrs = @group_values

      if group_attrs.first.respond_to?(:to_sym)
        association  = @klass.reflect_on_association(group_attrs.first.to_sym)
        associated   = group_attrs.size == 1 && association && association.macro == :belongs_to # only count belongs_to associations
        group_fields = Array(associated ? association.foreign_key : group_attrs)
      else
        group_fields = group_attrs
      end

      group_aliases = group_fields.map { |field| column_alias_for(field) }
      group_columns = group_aliases.zip(group_fields).map { |aliaz,field|
        [aliaz, column_for(field)]
      }

      group = @klass.connection.adapter_name == 'FrontBase' ? group_aliases : group_fields

      if operation == 'count' && column_name == :all
        aggregate_alias = 'count_all'
      else
        aggregate_alias = column_alias_for(operation, column_name)
      end

      select_values = [
        operation_over_aggregate_column(
          aggregate_column(column_name),
          operation,
          distinct).as(aggregate_alias)
      ]
      select_values += @select_values unless @having_values.empty?

      select_values.concat group_fields.zip(group_aliases).map { |field,aliaz|
        if field.respond_to?(:as)
          field.as(aliaz)
        else
          "#{field} AS #{aliaz}"
        end
      }

      relation = except(:group).group(group)
      relation.select_values = select_values

      calculated_data = @klass.connection.select_all(relation)

      if association
        key_ids     = calculated_data.collect { |row| row[group_aliases.first] }
        key_records = association.klass.base_class.find(key_ids)
        key_records = Hash[key_records.map { |r| [r.id, r] }]
      end

      ActiveSupport::OrderedHash[calculated_data.map do |row|
        key = group_columns.map { |aliaz, column|
          type_cast_calculated_value(row[aliaz], column)
        }
        key = key.first if key.size == 1
        key = key_records[key] if associated
        [key, type_cast_calculated_value(row[aggregate_alias], column_for(column_name), operation)]
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
      keys.map! {|k| k.respond_to?(:to_sql) ? k.to_sql : k}
      table_name = keys.join(' ')
      table_name.downcase!
      table_name.gsub!(/\*/, 'all')
      table_name.gsub!(/\W+/, ' ')
      table_name.strip!
      table_name.gsub!(/ +/, '_')

      @klass.connection.table_alias_for(table_name)
    end

    def column_for(field)
      field_name = field.respond_to?(:name) ? field.name.to_s : field.to_s.split('.').last
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

    def build_count_subquery(relation, column_name, distinct)
      column_alias = Arel.sql('count_column')
      subquery_alias = Arel.sql('subquery_for_count')

      aliased_column = aggregate_column(column_name == :all ? 1 : column_name).as(column_alias)
      relation.select_values = [aliased_column]
      subquery = relation.arel.as(subquery_alias)

      sm = Arel::SelectManager.new relation.engine
      select_value = operation_over_aggregate_column(column_alias, 'count', distinct)
      sm.project(select_value).from(subquery)
    end
  end
end
