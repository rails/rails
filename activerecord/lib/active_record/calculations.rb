module ActiveRecord
  module Calculations #:nodoc:
    CALCULATIONS_OPTIONS = [:conditions, :joins, :order, :select, :group, :having, :distinct, :limit, :offset, :include, :from]
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Count operates using three different approaches.
      #
      # * Count all: By not passing any parameters to count, it will return a count of all the rows for the model.
      # * Count using column: By passing a column name to count, it will return a count of all the rows for the model with supplied column present
      # * Count using options will find the row count matched by the options used.
      #
      # The third approach, count using options, accepts an option hash as the only parameter. The options are:
      #
      # * <tt>:conditions</tt>: An SQL fragment like "administrator = 1" or [ "user_name = ?", username ]. See conditions in the intro.
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

      # Calculates the average value on a given column.  The value is returned as a float.  See +calculate+ for examples with options.
      #
      #   Person.average('age')
      def average(column_name, options = {})
        calculate(:avg, column_name, options)
      end

      # Calculates the minimum value on a given column.  The value is returned with the same data type of the column.  See +calculate+ for examples with options.
      #
      #   Person.minimum('age')
      def minimum(column_name, options = {})
        calculate(:min, column_name, options)
      end

      # Calculates the maximum value on a given column.  The value is returned with the same data type of the column.  See +calculate+ for examples with options.
      #
      #   Person.maximum('age')
      def maximum(column_name, options = {})
        calculate(:max, column_name, options)
      end

      # Calculates the sum of values on a given column.  The value is returned with the same data type of the column.  See +calculate+ for examples with options.
      #
      #   Person.sum('age')
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
      # * <tt>:conditions</tt> - An SQL fragment like "administrator = 1" or [ "user_name = ?", username ]. See conditions in the intro.
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
        column_name     = options[:select] if options[:select]
        column_name     = '*' if column_name == :all
        column          = column_for column_name
        catch :invalid_query do
          if options[:group]
            return execute_grouped_calculation(operation, column_name, column, options)
          else
            return execute_simple_calculation(operation, column_name, column, options)
          end
        end
        0
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
          case args.size
          when 1
            args[0].is_a?(Hash) ? options = args[0] : column_name = args[0]
          when 2
            column_name, options = args
          else
            raise ArgumentError, "Unexpected parameters passed to count(): #{args.inspect}"
          end if args.size > 0
          
          [column_name, options]
        end

        def construct_calculation_sql(operation, column_name, options) #:nodoc:
          operation = operation.to_s.downcase
          options = options.symbolize_keys

          scope           = scope(:find)
          merged_includes = merge_includes(scope ? scope[:include] : [], options[:include])
          aggregate_alias = column_alias_for(operation, column_name)
          column_name     = "#{connection.quote_table_name(table_name)}.#{column_name}" if column_names.include?(column_name.to_s)

          if operation == 'count'
            if merged_includes.any?
              options[:distinct] = true
              column_name = options[:select] || [connection.quote_table_name(table_name), primary_key] * '.'
            end

            if options[:distinct]
              use_workaround = !connection.supports_count_distinct?
            end
          end

          if options[:distinct] && column_name.to_s !~ /\s*DISTINCT\s+/i
            distinct = 'DISTINCT ' 
          end
          sql = "SELECT #{operation}(#{distinct}#{column_name}) AS #{aggregate_alias}"

          # A (slower) workaround if we're using a backend, like sqlite, that doesn't support COUNT DISTINCT.
          sql = "SELECT COUNT(*) AS #{aggregate_alias}" if use_workaround

          sql << ", #{options[:group_field]} AS #{options[:group_alias]}" if options[:group]
          if options[:from]
            sql << " FROM #{options[:from]} "
          else
            sql << " FROM (SELECT #{distinct}#{column_name}" if use_workaround
            sql << " FROM #{connection.quote_table_name(table_name)} "
          end

          joins = ""
          add_joins!(joins, options, scope)

          if merged_includes.any?
            join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(self, merged_includes, joins)
            sql << join_dependency.join_associations.collect{|join| join.association_join }.join
          end

          sql << joins unless joins.blank?

          add_conditions!(sql, options[:conditions], scope)
          add_limited_ids_condition!(sql, options, join_dependency) if join_dependency && !using_limitable_reflections?(join_dependency.reflections) && ((scope && scope[:limit]) || options[:limit])

          if options[:group]
            group_key = connection.adapter_name == 'FrontBase' ?  :group_alias : :group_field
            sql << " GROUP BY #{options[group_key]} "
          end

          if options[:group] && options[:having]
            # FrontBase requires identifiers in the HAVING clause and chokes on function calls
            if connection.adapter_name == 'FrontBase'
              options[:having].downcase!
              options[:having].gsub!(/#{operation}\s*\(\s*#{column_name}\s*\)/, aggregate_alias)
            end

            sql << " HAVING #{options[:having]} "
          end

          sql << " ORDER BY #{options[:order]} "       if options[:order]
          add_limit!(sql, options, scope)
          sql << ") #{aggregate_alias}_subquery" if use_workaround
          sql
        end

        def execute_simple_calculation(operation, column_name, column, options) #:nodoc:
          value = connection.select_value(construct_calculation_sql(operation, column_name, options))
          type_cast_calculated_value(value, column, operation)
        end

        def execute_grouped_calculation(operation, column_name, column, options) #:nodoc:
          group_attr      = options[:group].to_s
          association     = reflect_on_association(group_attr.to_sym)
          associated      = association && association.macro == :belongs_to # only count belongs_to associations
          group_field     = associated ? association.primary_key_name : group_attr
          group_alias     = column_alias_for(group_field)
          group_column    = column_for group_field
          sql             = construct_calculation_sql(operation, column_name, options.merge(:group_field => group_field, :group_alias => group_alias))
          calculated_data = connection.select_all(sql)
          aggregate_alias = column_alias_for(operation, column_name)

          if association
            key_ids     = calculated_data.collect { |row| row[group_alias] }
            key_records = association.klass.base_class.find(key_ids)
            key_records = key_records.inject({}) { |hsh, r| hsh.merge(r.id => r) }
          end

          calculated_data.inject(ActiveSupport::OrderedHash.new) do |all, row|
            key   = type_cast_calculated_value(row[group_alias], group_column)
            key   = key_records[key] if associated
            value = row[aggregate_alias]
            all[key] = type_cast_calculated_value(value, column, operation)
            all
          end
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
          connection.table_alias_for(keys.join(' ').downcase.gsub(/\*/, 'all').gsub(/\W+/, ' ').strip.gsub(/ +/, '_'))
        end

        def column_for(field)
          field_name = field.to_s.split('.').last
          columns.detect { |c| c.name.to_s == field_name }
        end

        def type_cast_calculated_value(value, column, operation = nil)
          operation = operation.to_s.downcase
          case operation
            when 'count' then value.to_i
            when 'sum'   then type_cast_using_column(value || '0', column)
            when 'avg'   then value && value.to_d
            else type_cast_using_column(value, column)
          end
        end

        def type_cast_using_column(value, column)
          column ? column.type_cast(value) : value
        end
    end
  end
end
