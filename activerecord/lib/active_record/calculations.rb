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
        case args.size
        when 0
          construct_calculation_arel.count
        when 1
          if args[0].is_a?(Hash)
            options = args[0]
            distinct = options.has_key?(:distinct) ? options.delete(:distinct) : false
            construct_calculation_arel(options).count(options[:select], :distinct => distinct)
          else
            construct_calculation_arel.count(args[0])
          end
        when 2
          column_name, options = args
          distinct = options.has_key?(:distinct) ? options.delete(:distinct) : false
          construct_calculation_arel(options).count(column_name, :distinct => distinct)
        else
          raise ArgumentError, "Unexpected parameters passed to count(): #{args.inspect}"
        end
      rescue ThrowResult
        0
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
        construct_calculation_arel(options).calculate(operation, column_name, options.slice(:distinct))
      rescue ThrowResult
        0
      end

      private
        def validate_calculation_options(options = {})
          options.assert_valid_keys(CALCULATIONS_OPTIONS)
        end

        def construct_calculation_arel(options = {})
          validate_calculation_options(options)
          options = options.except(:distinct)

          merge_with_includes = current_scoped_methods ? current_scoped_methods.includes_values : []
          includes = (merge_with_includes + Array.wrap(options[:include])).uniq

          if includes.any?
            merge_with_joins = current_scoped_methods ? current_scoped_methods.joins_values : []
            joins = (merge_with_joins + Array.wrap(options[:joins])).uniq
            join_dependency = ActiveRecord::Associations::ClassMethods::JoinDependency.new(self, includes, construct_join(joins))
            construct_finder_arel_with_included_associations(options, join_dependency)
          else
            scoped.apply_finder_options(options)
          end
        end

    end
  end
end
