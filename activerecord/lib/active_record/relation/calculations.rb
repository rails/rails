# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveRecord
  # = Active Record \Calculations
  module Calculations
    class ColumnAliasTracker # :nodoc:
      def initialize(connection)
        @connection = connection
        @aliases = Hash.new(0)
      end

      def alias_for(field)
        aliased_name = column_alias_for(field)

        if @aliases[aliased_name] == 0
          @aliases[aliased_name] = 1
          aliased_name
        else
          # Update the count
          count = @aliases[aliased_name] += 1
          "#{truncate(aliased_name)}_#{count}"
        end
      end

      private
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
          @connection.table_alias_for(column_alias)
        end

        def truncate(name)
          name.slice(0, @connection.table_alias_length - 2)
        end
    end

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
    # If +count+ is used with {Relation#group}[rdoc-ref:QueryMethods#group],
    # it returns a Hash whose keys represent the aggregated column,
    # and the values are the respective amounts:
    #
    #   Person.group(:city).count
    #   # => { 'Rome' => 5, 'Paris' => 3 }
    #
    # If +count+ is used with {Relation#group}[rdoc-ref:QueryMethods#group] for multiple columns, it returns a Hash whose
    # keys are an array containing the individual values of each column and the value
    # of each key would be the count.
    #
    #   Article.group(:status, :category).count
    #   # =>  {["draft", "business"]=>10, ["draft", "technology"]=>4, ["published", "technology"]=>2}
    #
    # If +count+ is used with {Relation#select}[rdoc-ref:QueryMethods#select], it will count the selected columns:
    #
    #   Person.select(:age).count
    #   # => counts the number of different age values
    #
    # Note: not all valid {Relation#select}[rdoc-ref:QueryMethods#select] expressions are valid +count+ expressions. The specifics differ
    # between databases. In invalid cases, an error from the database is thrown.
    #
    # When given a block, calls the block with each record in the relation and
    # returns the number of records for which the block returns a truthy value.
    #
    #   Person.count { |person| person.age > 21 }
    #   # => counts the number of people older that 21
    #
    # If the relation hasn't been loaded yet, calling +count+ with a block will
    # load all records in the relation. If there are a lot of records in the
    # relation, loading all records could result in performance issues.
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

    # Same as #count, but performs the query asynchronously and returns an
    # ActiveRecord::Promise.
    def async_count(column_name = nil)
      async.count(column_name)
    end

    # Calculates the average value on a given column. Returns +nil+ if there's
    # no row. See #calculate for examples with options.
    #
    #   Person.average(:age) # => 35.8
    def average(column_name)
      calculate(:average, column_name)
    end

    # Same as #average, but performs the query asynchronously and returns an
    # ActiveRecord::Promise.
    def async_average(column_name)
      async.average(column_name)
    end

    # Calculates the minimum value on a given column. The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # #calculate for examples with options.
    #
    #   Person.minimum(:age) # => 7
    def minimum(column_name)
      calculate(:minimum, column_name)
    end

    # Same as #minimum, but performs the query asynchronously and returns an
    # ActiveRecord::Promise.
    def async_minimum(column_name)
      async.minimum(column_name)
    end

    # Calculates the maximum value on a given column. The value is returned
    # with the same data type of the column, or +nil+ if there's no row. See
    # #calculate for examples with options.
    #
    #   Person.maximum(:age) # => 93
    def maximum(column_name)
      calculate(:maximum, column_name)
    end

    # Same as #maximum, but performs the query asynchronously and returns an
    # ActiveRecord::Promise.
    def async_maximum(column_name)
      async.maximum(column_name)
    end

    # Calculates the sum of values on a given column. The value is returned
    # with the same data type of the column, +0+ if there's no row. See
    # #calculate for examples with options.
    #
    #   Person.sum(:age) # => 4562
    #
    # When given a block, calls the block with each record in the relation and
    # returns the sum of +initial_value_or_column+ plus the block return values:
    #
    #   Person.sum { |person| person.age } # => 4562
    #   Person.sum(1000) { |person| person.age } # => 5562
    #
    # If the relation hasn't been loaded yet, calling +sum+ with a block will
    # load all records in the relation. If there are a lot of records in the
    # relation, loading all records could result in performance issues.
    def sum(initial_value_or_column = 0, &block)
      if block_given?
        map(&block).sum(initial_value_or_column)
      else
        calculate(:sum, initial_value_or_column)
      end
    end

    # Same as #sum, but performs the query asynchronously and returns an
    # ActiveRecord::Promise.
    def async_sum(identity_or_column = nil)
      async.sum(identity_or_column)
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
      operation = operation.to_s.downcase

      if @none
        case operation
        when "count", "sum"
          result = group_values.any? ? Hash.new : 0
          return @async ? Promise::Complete.new(result) : result
        when "average", "minimum", "maximum"
          result = group_values.any? ? Hash.new : nil
          return @async ? Promise::Complete.new(result) : result
        end
      end

      if has_include?(column_name)
        relation = apply_join_dependency

        if operation == "count"
          unless distinct_value || distinct_select?(column_name || select_for_count)
            relation.distinct!
            relation.select_values = Array(model.primary_key || table[Arel.star])
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
    # loading an entire record object per row.
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
    #   Comment.joins(:person).pluck(:id, person: :id)
    #   # SELECT comments.id, person.id FROM comments INNER JOIN people person ON person.id = comments.person_id
    #   # => [[1, 2], [2, 2]]
    #
    #   Comment.joins(:person).pluck(:id, person: [:id, :name])
    #   # SELECT comments.id, person.id, person.name FROM comments INNER JOIN people person ON person.id = comments.person_id
    #   # => [[1, 2, 'David'], [2, 2, 'David']]
    #
    #   Person.pluck(Arel.sql('DATEDIFF(updated_at, created_at)'))
    #   # SELECT DATEDIFF(updated_at, created_at) FROM people
    #   # => ['0', '27761', '173']
    #
    # Be aware that #pluck ignores any previous select clauses
    #
    #   Person.select(:name).pluck(:id)
    #   # SELECT people.id FROM people
    #
    # See also #ids.
    def pluck(*column_names)
      if @none
        if @async
          return Promise::Complete.new([])
        else
          return []
        end
      end

      if loaded? && all_attributes?(column_names)
        result = records.pluck(*column_names)
        if @async
          return Promise::Complete.new(result)
        else
          return result
        end
      end

      if has_include?(column_names.first)
        relation = apply_join_dependency
        relation.pluck(*column_names)
      else
        model.disallow_raw_sql!(flattened_args(column_names))
        relation = spawn
        columns = relation.arel_columns(column_names)
        relation.select_values = columns
        result = skip_query_cache_if_necessary do
          if where_clause.contradiction? && !possible_aggregation?(column_names)
            ActiveRecord::Result.empty(async: @async)
          else
            model.with_connection do |c|
              c.select_all(relation.arel, "#{model.name} Pluck", async: @async)
            end
          end
        end
        result.then do |result|
          type_cast_pluck_values(result, columns)
        end
      end
    end

    # Same as #pluck, but performs the query asynchronously and returns an
    # ActiveRecord::Promise.
    def async_pluck(*column_names)
      async.pluck(*column_names)
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
        result = records.pick(*column_names)
        return @async ? Promise::Complete.new(result) : result
      end

      limit(1).pluck(*column_names).then(&:first)
    end

    # Same as #pick, but performs the query asynchronously and returns an
    # ActiveRecord::Promise.
    def async_pick(*column_names)
      async.pick(*column_names)
    end

    # Returns the base model's ID's for the relation using the table's primary key
    #
    #   Person.ids # SELECT people.id FROM people
    #   Person.joins(:company).ids # SELECT people.id FROM people INNER JOIN companies ON companies.id = people.company_id
    def ids
      primary_key_array = Array(primary_key)

      if loaded?
        result = records.map do |record|
          if primary_key_array.one?
            record._read_attribute(primary_key_array.first)
          else
            primary_key_array.map { |column| record._read_attribute(column) }
          end
        end
        return @async ? Promise::Complete.new(result) : result
      end

      if has_include?(primary_key)
        relation = apply_join_dependency.group(*primary_key_array)
        return relation.ids
      end

      columns = arel_columns(primary_key_array)
      relation = spawn
      relation.select_values = columns

      result = if relation.where_clause.contradiction?
        ActiveRecord::Result.empty
      else
        skip_query_cache_if_necessary do
          model.with_connection do |c|
            c.select_all(relation, "#{model.name} Ids", async: @async)
          end
        end
      end

      result.then { |result| type_cast_pluck_values(result, columns) }
    end

    # Same as #ids, but performs the query asynchronously and returns an
    # ActiveRecord::Promise.
    def async_ids
      async.ids
    end

    protected
      def aggregate_column(column_name)
        case column_name
        when Arel::Expressions
          column_name
        when :all
          Arel.star
        else
          arel_column(column_name.to_s)
        end
      end

    private
      def all_attributes?(column_names)
        (column_names.map(&:to_s) - model.attribute_names - model.attribute_aliases.keys).empty?
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

      def possible_aggregation?(column_names)
        column_names.all? do |column_name|
          if column_name.is_a?(String)
            column_name.include?("(")
          else
            Arel.arel_node?(column_name)
          end
        end
      end

      def operation_over_aggregate_column(column, operation, distinct)
        operation == "count" ? column.count(distinct) : column.public_send(operation)
      end

      def execute_simple_calculation(operation, column_name, distinct) # :nodoc:
        if build_count_subquery?(operation, column_name, distinct)
          # Shortcut when limit is zero.
          return 0 if limit_value == 0

          relation = self
          query_builder = build_count_subquery(spawn, column_name, distinct)
        else
          # PostgreSQL doesn't like ORDER BY when there are no GROUP BY
          relation = unscope(:order).distinct!(false)

          column = relation.aggregate_column(column_name)
          select_value = operation_over_aggregate_column(column, operation, distinct)
          select_value.distinct = true if operation == "sum" && distinct

          relation.select_values = [select_value]

          query_builder = relation.arel
        end

        query_result = if relation.where_clause.contradiction?
          if @async
            FutureResult.wrap(ActiveRecord::Result.empty)
          else
            ActiveRecord::Result.empty
          end
        else
          skip_query_cache_if_necessary do
            model.with_connection do |c|
              c.select_all(query_builder, "#{model.name} #{operation.capitalize}", async: @async)
            end
          end
        end

        query_result.then do |result|
          if operation != "count"
            type = column.try(:type_caster) ||
              lookup_cast_type_from_join_dependencies(column_name.to_s) || Type.default_value
            type = type.subtype if Enum::EnumType === type
          end

          type_cast_calculated_value(result.cast_values.first, operation, type)
        end
      end

      def execute_grouped_calculation(operation, column_name, distinct) # :nodoc:
        group_fields = group_values

        if group_fields.size == 1 && group_fields.first.respond_to?(:to_sym)
          association  = model._reflect_on_association(group_fields.first)
          associated   = association && association.belongs_to? # only count belongs_to associations
          group_fields = Array(association.foreign_key) if associated
        end

        relation = except(:group).distinct!(false)
        group_fields = relation.arel_columns(group_fields)

        model.with_connection do |connection|
          column_alias_tracker = ColumnAliasTracker.new(connection)

          group_aliases = group_fields.map { |field|
            field = connection.visitor.compile(field) if Arel.arel_node?(field)
            column_alias_tracker.alias_for(field.to_s.downcase)
          }
          group_columns = group_aliases.zip(group_fields)

          column = relation.aggregate_column(column_name)
          column_alias = column_alias_tracker.alias_for("#{operation} #{column_name.to_s.downcase}")
          select_value = operation_over_aggregate_column(column, operation, distinct)
          select_value = select_value.as(model.adapter_class.quote_column_name(column_alias))

          select_values = [select_value]
          select_values += self.select_values unless having_clause.empty?

          select_values.concat group_columns.map { |aliaz, field|
            aliaz = model.adapter_class.quote_column_name(aliaz)
            if field.respond_to?(:as)
              field.as(aliaz)
            else
              "#{field} AS #{aliaz}"
            end
          }

          relation.group_values  = group_fields
          relation.select_values = select_values

          result = skip_query_cache_if_necessary do
            connection.select_all(relation.arel, "#{model.name} #{operation.capitalize}", async: @async)
          end

          result.then do |calculated_data|
            if association
              key_ids     = calculated_data.collect { |row| row[group_aliases.first] }
              key_records = association.klass.base_class.where(association.klass.base_class.primary_key => key_ids)
              key_records = key_records.index_by(&:id)
            end

            key_types = group_columns.each_with_object({}) do |(aliaz, col_name), types|
              types[aliaz] = col_name.try(:type_caster) ||
                type_for(col_name) do
                  calculated_data.column_types.fetch(aliaz, Type.default_value)
                end
            end

            hash_rows = calculated_data.cast_values(key_types).map! do |row|
              calculated_data.columns.each_with_object({}).with_index do |(col_name, hash), i|
                hash[col_name] = row[i]
              end
            end

            if operation != "count"
              type = column.try(:type_caster) ||
                lookup_cast_type_from_join_dependencies(column_name.to_s) || Type.default_value
              type = type.subtype if Enum::EnumType === type
            end

            hash_rows.each_with_object({}) do |row, result|
              key = group_aliases.map { |aliaz| row[aliaz] }
              key = key.first if key.size == 1
              key = key_records[key] if associated

              result[key] = type_cast_calculated_value(row[column_alias], operation, type)
            end
          end
        end
      end

      def type_for(field, &block)
        field_name = field.respond_to?(:name) ? field.name.to_s : field.to_s.split(".").last
        model.type_for_attribute(field_name, &block)
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
          model.attribute_types
        else
          join_dependencies = nil
          columns.map.with_index do |column, i|
            column.try(:type_caster) ||
              model.attribute_types.fetch(name = result.columns[i]) do
                join_dependencies ||= build_join_dependencies
                lookup_cast_type_from_join_dependencies(name, join_dependencies) ||
                  result.column_types[i] || Type.default_value
              end
          end
        end
        result.cast_values(cast_types)
      end

      def type_cast_calculated_value(value, operation, type)
        case operation
        when "count"
          value.to_i
        when "sum"
          type.deserialize(value || 0)
        when "average"
          case type.type
          when :integer, :decimal
            value&.to_d
          else
            type.deserialize(value)
          end
        else # "minimum", "maximum"
          type.deserialize(value)
        end
      end

      def select_for_count
        if select_values.empty?
          :all
        else
          with_connection do |conn|
            arel_columns(select_values).map { |column| conn.visitor.compile(column) }.join(", ")
          end
        end
      end

      def build_count_subquery?(operation, column_name, distinct)
        # SQLite and older MySQL does not support `COUNT DISTINCT` with `*` or
        # multiple columns, so we need to use subquery for this.
        operation == "count" &&
          (((column_name == :all || select_values.many?) && distinct) || has_limit_or_offset?)
      end

      def build_count_subquery(relation, column_name, distinct)
        if column_name == :all
          column_alias = Arel.star
          relation.select_values = [ Arel.sql(FinderMethods::ONE_AS_ONE) ] unless distinct
          relation.unscope!(:order)
        else
          column_alias = Arel.sql("count_column")
          relation.select_values = [ relation.aggregate_column(column_name).as(column_alias) ]
        end

        subquery_alias = Arel.sql("subquery_for_count", retryable: true)
        select_value = operation_over_aggregate_column(column_alias, "count", false)

        relation.build_subquery(subquery_alias, select_value)
      end
  end
end
