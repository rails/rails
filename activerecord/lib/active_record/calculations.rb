module ActiveRecord
  module Calculations #:nodoc:
    extend ActiveSupport::Concern

    CALCULATIONS_OPTIONS = [:conditions, :joins, :order, :select, :group, :having, :distinct, :limit, :offset, :include, :from]

    module ClassMethods
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
      def count(*args)
        calculate(:count, *construct_count_options_from_args(*args))
      end

      # Calculates the average value on a given column. The value is returned as
      # a float, or +nil+ if there's no row. See +calculate+ for examples with
      # options.
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
        validate_calculation_options(operation, options)
        operation = operation.to_s.downcase

        scope = scope(:find)

        merged_includes = merge_includes(scope ? scope[:include] : [], options[:include])

        if operation == "count"
          if merged_includes.any?
            distinct = true
            column_name = options[:select] || primary_key
          end

          distinct = nil if column_name.to_s =~ /\s*DISTINCT\s+/i
          distinct ||= options[:distinct]
        else
          distinct = nil
        end

        catch :invalid_query do
          relation = if merged_includes.any?
            join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(self, merged_includes, construct_join(options[:joins], scope))
            construct_finder_arel_with_included_associations(options, join_dependency)
          else
            relation = arel_table(options[:from]).
              joins(construct_join(options[:joins], scope)).
              conditions(construct_conditions(options[:conditions], scope)).
              order(options[:order]).
              limit(options[:limit]).
              offset(options[:offset])
          end
          if options[:group]
            return execute_grouped_calculation(operation, column_name, options, relation)
          else
            return execute_simple_calculation(operation, column_name, options.merge(:distinct => distinct), relation)
          end
        end
        0
      end

      def execute_simple_calculation(operation, column_name, options, relation) #:nodoc:
        column = if column_names.include?(column_name.to_s)
          Arel::Attribute.new(arel_table(options[:from] || table_name),
                              options[:select] || column_name)
        else
          Arel::SqlLiteral.new(options[:select] ||
                               (column_name == :all ? "*" : column_name.to_s))
        end

        relation = relation.select(operation == 'count' ? column.count(options[:distinct]) : column.send(operation))

        type_cast_calculated_value(connection.select_value(relation.to_sql), column_for(column_name), operation)
      end

      def execute_grouped_calculation(operation, column_name, options, relation) #:nodoc:
        group_attr      = options[:group].to_s
        association     = reflect_on_association(group_attr.to_sym)
        associated      = association && association.macro == :belongs_to # only count belongs_to associations
        group_field     = associated ? association.primary_key_name : group_attr
        group_alias     = column_alias_for(group_field)
        group_column    = column_for group_field

        options[:group] = connection.adapter_name == 'FrontBase' ?  group_alias : group_field

        aggregate_alias = column_alias_for(operation, column_name)

        options[:select] = (operation == 'count' && column_name == :all) ?
          "COUNT(*) AS count_all" :
          Arel::Attribute.new(arel_table, column_name).send(operation).as(aggregate_alias).to_sql

        options[:select] <<  ", #{group_field} AS #{group_alias}"

        relation = relation.select(options[:select]).group(construct_group(options[:group], options[:having], nil))

        calculated_data = connection.select_all(relation.to_sql)

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

     protected
        def construct_count_options_from_args(*args)
          options     = {}
          column_name = :all

          # We need to handle
          #   count()
          #   count(:column_name=:all)
          #   count(options={})
          #   count(column_name=:all, options={})
          #   selects specified by scopes
          case args.size
          when 0
            column_name = scope(:find)[:select] if scope(:find)
          when 1
            if args[0].is_a?(Hash)
              column_name = scope(:find)[:select] if scope(:find)
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

      private
        def validate_calculation_options(operation, options = {})
          options.assert_valid_keys(CALCULATIONS_OPTIONS)
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

          connection.table_alias_for(table_name)
        end

        def column_for(field)
          field_name = field.to_s.split('.').last
          columns.detect { |c| c.name.to_s == field_name }
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
    end
  end
end
