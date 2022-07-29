# frozen_string_literal: true

require "active_support/core_ext/string/filters"

module ActiveRecord
  module FinderMethods
    ONE_AS_ONE = "1 AS one"

    # Find by id - This can either be a specific id (1), a list of ids (1, 5, 6), or an array of ids ([5, 6, 10]).
    # If one or more records cannot be found for the requested ids, then ActiveRecord::RecordNotFound will be raised.
    # If the primary key is an integer, find by id coerces its arguments by using +to_i+.
    #
    #   Person.find(1)          # returns the object for ID = 1
    #   Person.find("1")        # returns the object for ID = 1
    #   Person.find("31-sarah") # returns the object for ID = 31
    #   Person.find(1, 2, 6)    # returns an array for objects with IDs in (1, 2, 6)
    #   Person.find([7, 17])    # returns an array for objects with IDs in (7, 17)
    #   Person.find([1])        # returns an array for the object with ID = 1
    #   Person.where("administrator = 1").order("created_on DESC").find(1)
    #
    # NOTE: The returned records are in the same order as the ids you provide.
    # If you want the results to be sorted by database, you can use ActiveRecord::QueryMethods#where
    # method and provide an explicit ActiveRecord::QueryMethods#order option.
    # But ActiveRecord::QueryMethods#where method doesn't raise ActiveRecord::RecordNotFound.
    #
    # ==== Find with lock
    #
    # Example for find with a lock: Imagine two concurrent transactions:
    # each will read <tt>person.visits == 2</tt>, add 1 to it, and save, resulting
    # in two saves of <tt>person.visits = 3</tt>. By locking the row, the second
    # transaction has to wait until the first is finished; we get the
    # expected <tt>person.visits == 4</tt>.
    #
    #   Person.transaction do
    #     person = Person.lock(true).find(1)
    #     person.visits += 1
    #     person.save!
    #   end
    #
    # ==== Variations of #find
    #
    #   Person.where(name: 'Spartacus', rating: 4)
    #   # returns a chainable list (which can be empty).
    #
    #   Person.find_by(name: 'Spartacus', rating: 4)
    #   # returns the first item or nil.
    #
    #   Person.find_or_initialize_by(name: 'Spartacus', rating: 4)
    #   # returns the first item or returns a new instance (requires you call .save to persist against the database).
    #
    #   Person.find_or_create_by(name: 'Spartacus', rating: 4)
    #   # returns the first item or creates it and returns it.
    #
    # ==== Alternatives for #find
    #
    #   Person.where(name: 'Spartacus', rating: 4).exists?(conditions = :none)
    #   # returns a boolean indicating if any record with the given conditions exist.
    #
    #   Person.where(name: 'Spartacus', rating: 4).select("field1, field2, field3")
    #   # returns a chainable list of instances with only the mentioned fields.
    #
    #   Person.where(name: 'Spartacus', rating: 4).ids
    #   # returns an Array of ids.
    #
    #   Person.where(name: 'Spartacus', rating: 4).pluck(:field1, :field2)
    #   # returns an Array of the required fields.
    def find(*args)
      return super if block_given?
      find_with_ids(*args)
    end

    # Finds the first record matching the specified conditions. There
    # is no implied ordering so if order matters, you should specify it
    # yourself.
    #
    # If no record is found, returns <tt>nil</tt>.
    #
    #   Post.find_by name: 'Spartacus', rating: 4
    #   Post.find_by "published_at < ?", 2.weeks.ago
    def find_by(arg, *args)
      where(arg, *args).take
    end

    # Like #find_by, except that if no record is found, raises
    # an ActiveRecord::RecordNotFound error.
    def find_by!(arg, *args)
      where(arg, *args).take!
    end

    # Gives a record (or N records if a parameter is supplied) without any implied
    # order. The order will depend on the database implementation.
    # If an order is supplied it will be respected.
    #
    #   Person.take # returns an object fetched by SELECT * FROM people LIMIT 1
    #   Person.take(5) # returns 5 objects fetched by SELECT * FROM people LIMIT 5
    #   Person.where(["name LIKE '%?'", name]).take
    def take(limit = nil)
      limit ? find_take_with_limit(limit) : find_take
    end

    # Same as #take but raises ActiveRecord::RecordNotFound if no record
    # is found. Note that #take! accepts no arguments.
    def take!
      take || raise_record_not_found_exception!
    end

    # Finds the sole matching record. Raises ActiveRecord::RecordNotFound if no
    # record is found. Raises ActiveRecord::SoleRecordExceeded if more than one
    # record is found.
    #
    #   Product.where(["price = %?", price]).sole
    def sole
      found, undesired = first(2)

      if found.nil?
        raise_record_not_found_exception!
      elsif undesired.present?
        raise ActiveRecord::SoleRecordExceeded.new(self)
      else
        found
      end
    end

    # Finds the sole matching record. Raises ActiveRecord::RecordNotFound if no
    # record is found. Raises ActiveRecord::SoleRecordExceeded if more than one
    # record is found.
    #
    #   Product.find_sole_by(["price = %?", price])
    def find_sole_by(arg, *args)
      where(arg, *args).sole
    end

    # Find the first record (or first N records if a parameter is supplied).
    # If no order is defined it will order by primary key.
    #
    #   Person.first # returns the first object fetched by SELECT * FROM people ORDER BY people.id LIMIT 1
    #   Person.where(["user_name = ?", user_name]).first
    #   Person.where(["user_name = :u", { u: user_name }]).first
    #   Person.order("created_on DESC").offset(5).first
    #   Person.first(3) # returns the first three objects fetched by SELECT * FROM people ORDER BY people.id LIMIT 3
    #
    def first(limit = nil)
      if limit
        find_nth_with_limit(0, limit)
      else
        find_nth 0
      end
    end

    # Same as #first but raises ActiveRecord::RecordNotFound if no record
    # is found. Note that #first! accepts no arguments.
    def first!
      first || raise_record_not_found_exception!
    end

    # Find the last record (or last N records if a parameter is supplied).
    # If no order is defined it will order by primary key.
    #
    #   Person.last # returns the last object fetched by SELECT * FROM people
    #   Person.where(["user_name = ?", user_name]).last
    #   Person.order("created_on DESC").offset(5).last
    #   Person.last(3) # returns the last three objects fetched by SELECT * FROM people.
    #
    # Take note that in that last case, the results are sorted in ascending order:
    #
    #   [#<Person id:2>, #<Person id:3>, #<Person id:4>]
    #
    # and not:
    #
    #   [#<Person id:4>, #<Person id:3>, #<Person id:2>]
    def last(limit = nil)
      return find_last(limit) if loaded? || has_limit_or_offset?

      result = ordered_relation.limit(limit)
      result = result.reverse_order!

      limit ? result.reverse : result.first
    end

    # Same as #last but raises ActiveRecord::RecordNotFound if no record
    # is found. Note that #last! accepts no arguments.
    def last!
      last || raise_record_not_found_exception!
    end

    # Find the second record.
    # If no order is defined it will order by primary key.
    #
    #   Person.second # returns the second object fetched by SELECT * FROM people
    #   Person.offset(3).second # returns the second object from OFFSET 3 (which is OFFSET 4)
    #   Person.where(["user_name = :u", { u: user_name }]).second
    def second
      find_nth 1
    end

    # Same as #second but raises ActiveRecord::RecordNotFound if no record
    # is found.
    def second!
      second || raise_record_not_found_exception!
    end

    # Find the third record.
    # If no order is defined it will order by primary key.
    #
    #   Person.third # returns the third object fetched by SELECT * FROM people
    #   Person.offset(3).third # returns the third object from OFFSET 3 (which is OFFSET 5)
    #   Person.where(["user_name = :u", { u: user_name }]).third
    def third
      find_nth 2
    end

    # Same as #third but raises ActiveRecord::RecordNotFound if no record
    # is found.
    def third!
      third || raise_record_not_found_exception!
    end

    # Find the fourth record.
    # If no order is defined it will order by primary key.
    #
    #   Person.fourth # returns the fourth object fetched by SELECT * FROM people
    #   Person.offset(3).fourth # returns the fourth object from OFFSET 3 (which is OFFSET 6)
    #   Person.where(["user_name = :u", { u: user_name }]).fourth
    def fourth
      find_nth 3
    end

    # Same as #fourth but raises ActiveRecord::RecordNotFound if no record
    # is found.
    def fourth!
      fourth || raise_record_not_found_exception!
    end

    # Find the fifth record.
    # If no order is defined it will order by primary key.
    #
    #   Person.fifth # returns the fifth object fetched by SELECT * FROM people
    #   Person.offset(3).fifth # returns the fifth object from OFFSET 3 (which is OFFSET 7)
    #   Person.where(["user_name = :u", { u: user_name }]).fifth
    def fifth
      find_nth 4
    end

    # Same as #fifth but raises ActiveRecord::RecordNotFound if no record
    # is found.
    def fifth!
      fifth || raise_record_not_found_exception!
    end

    # Find the forty-second record. Also known as accessing "the reddit".
    # If no order is defined it will order by primary key.
    #
    #   Person.forty_two # returns the forty-second object fetched by SELECT * FROM people
    #   Person.offset(3).forty_two # returns the forty-second object from OFFSET 3 (which is OFFSET 44)
    #   Person.where(["user_name = :u", { u: user_name }]).forty_two
    def forty_two
      find_nth 41
    end

    # Same as #forty_two but raises ActiveRecord::RecordNotFound if no record
    # is found.
    def forty_two!
      forty_two || raise_record_not_found_exception!
    end

    # Find the third-to-last record.
    # If no order is defined it will order by primary key.
    #
    #   Person.third_to_last # returns the third-to-last object fetched by SELECT * FROM people
    #   Person.offset(3).third_to_last # returns the third-to-last object from OFFSET 3
    #   Person.where(["user_name = :u", { u: user_name }]).third_to_last
    def third_to_last
      find_nth_from_last 3
    end

    # Same as #third_to_last but raises ActiveRecord::RecordNotFound if no record
    # is found.
    def third_to_last!
      third_to_last || raise_record_not_found_exception!
    end

    # Find the second-to-last record.
    # If no order is defined it will order by primary key.
    #
    #   Person.second_to_last # returns the second-to-last object fetched by SELECT * FROM people
    #   Person.offset(3).second_to_last # returns the second-to-last object from OFFSET 3
    #   Person.where(["user_name = :u", { u: user_name }]).second_to_last
    def second_to_last
      find_nth_from_last 2
    end

    # Same as #second_to_last but raises ActiveRecord::RecordNotFound if no record
    # is found.
    def second_to_last!
      second_to_last || raise_record_not_found_exception!
    end

    # Returns true if a record exists in the table that matches the +id+ or
    # conditions given, or false otherwise. The argument can take six forms:
    #
    # * Integer - Finds the record with this primary key.
    # * String - Finds the record with a primary key corresponding to this
    #   string (such as <tt>'5'</tt>).
    # * Array - Finds the record that matches these +where+-style conditions
    #   (such as <tt>['name LIKE ?', "%#{query}%"]</tt>).
    # * Hash - Finds the record that matches these +where+-style conditions
    #   (such as <tt>{name: 'David'}</tt>).
    # * +false+ - Returns always +false+.
    # * No args - Returns +false+ if the relation is empty, +true+ otherwise.
    #
    # For more information about specifying conditions as a hash or array,
    # see the Conditions section in the introduction to ActiveRecord::Base.
    #
    # Note: You can't pass in a condition as a string (like <tt>name =
    # 'Jamie'</tt>), since it would be sanitized and then queried against
    # the primary key column, like <tt>id = 'name = \'Jamie\''</tt>.
    #
    #   Person.exists?(5)
    #   Person.exists?('5')
    #   Person.exists?(['name LIKE ?', "%#{query}%"])
    #   Person.exists?(id: [1, 4, 8])
    #   Person.exists?(name: 'David')
    #   Person.exists?(false)
    #   Person.exists?
    #   Person.where(name: 'Spartacus', rating: 4).exists?
    def exists?(conditions = :none)
      if Base === conditions
        raise ArgumentError, <<-MSG.squish
          You are passing an instance of ActiveRecord::Base to `exists?`.
          Please pass the id of the object by calling `.id`.
        MSG
      end

      return false if !conditions || limit_value == 0

      if eager_loading?
        relation = apply_join_dependency(eager_loading: false)
        return relation.exists?(conditions)
      end

      relation = construct_relation_for_exists(conditions)
      return false if relation.where_clause.contradiction?

      skip_query_cache_if_necessary { connection.select_rows(relation.arel, "#{name} Exists?").size == 1 }
    end

    # Returns true if the relation contains the given record or false otherwise.
    #
    # No query is performed if the relation is loaded; the given record is
    # compared to the records in memory. If the relation is unloaded, an
    # efficient existence query is performed, as in #exists?.
    def include?(record)
      if loaded? || offset_value || limit_value || having_clause.any?
        records.include?(record)
      else
        record.is_a?(klass) && exists?(record.id)
      end
    end

    alias :member? :include?

    # This method is called whenever no records are found with either a single
    # id or multiple ids and raises an ActiveRecord::RecordNotFound exception.
    #
    # The error message is different depending on whether a single id or
    # multiple ids are provided. If multiple ids are provided, then the number
    # of results obtained should be provided in the +result_size+ argument and
    # the expected number of results should be provided in the +expected_size+
    # argument.
    def raise_record_not_found_exception!(ids = nil, result_size = nil, expected_size = nil, key = primary_key, not_found_ids = nil) # :nodoc:
      conditions = " [#{arel.where_sql(klass)}]" unless where_clause.empty?

      name = @klass.name

      if ids.nil?
        error = +"Couldn't find #{name}"
        error << " with#{conditions}" if conditions
        raise RecordNotFound.new(error, name, key)
      elsif Array.wrap(ids).size == 1
        error = "Couldn't find #{name} with '#{key}'=#{ids}#{conditions}"
        raise RecordNotFound.new(error, name, key, ids)
      else
        error = +"Couldn't find all #{name.pluralize} with '#{key}': "
        error << "(#{ids.join(", ")})#{conditions} (found #{result_size} results, but was looking for #{expected_size})."
        error << " Couldn't find #{name.pluralize(not_found_ids.size)} with #{key.to_s.pluralize(not_found_ids.size)} #{not_found_ids.join(', ')}." if not_found_ids
        raise RecordNotFound.new(error, name, key, ids)
      end
    end

    private
      def construct_relation_for_exists(conditions)
        conditions = sanitize_forbidden_attributes(conditions)

        if distinct_value && offset_value
          relation = except(:order).limit!(1)
        else
          relation = except(:select, :distinct, :order)._select!(ONE_AS_ONE).limit!(1)
        end

        case conditions
        when Array, Hash
          relation.where!(conditions) unless conditions.empty?
        else
          relation.where!(primary_key => conditions) unless conditions == :none
        end

        relation
      end

      def apply_join_dependency(eager_loading: group_values.empty?)
        join_dependency = construct_join_dependency(
          eager_load_values | includes_values, Arel::Nodes::OuterJoin
        )
        relation = except(:includes, :eager_load, :preload).joins!(join_dependency)

        if eager_loading && has_limit_or_offset? && !(
            using_limitable_reflections?(join_dependency.reflections) &&
            using_limitable_reflections?(
              construct_join_dependency(
                select_association_list(joins_values).concat(
                  select_association_list(left_outer_joins_values)
                ), nil
              ).reflections
            )
          )
          relation = skip_query_cache_if_necessary do
            klass.connection.distinct_relation_for_primary_key(relation)
          end
        end

        if block_given?
          yield relation, join_dependency
        else
          relation
        end
      end

      def using_limitable_reflections?(reflections)
        reflections.none?(&:collection?)
      end

      def find_with_ids(*ids)
        raise UnknownPrimaryKey.new(@klass) if primary_key.nil?

        expects_array = ids.first.kind_of?(Array)
        return [] if expects_array && ids.first.empty?

        ids = ids.flatten.compact.uniq

        model_name = @klass.name
        _select!(table[primary_key]) unless select_values.empty?

        case ids.size
        when 0
          error_message = "Couldn't find #{model_name} without an ID"
          raise RecordNotFound.new(error_message, model_name, primary_key)
        when 1
          result = find_one(ids.first)
          expects_array ? [ result ] : result
        else
          find_some(ids)
        end
      end

      def find_one(id)
        if ActiveRecord::Base === id
          raise ArgumentError, <<-MSG.squish
            You are passing an instance of ActiveRecord::Base to `find`.
            Please pass the id of the object by calling `.id`.
          MSG
        end

        relation = where(primary_key => id)
        record = relation.take

        raise_record_not_found_exception!(id, 0, 1) unless record

        record
      end

      def find_some(ids)
        return find_some_ordered(ids) unless order_values.present?

        result = where(primary_key => ids).to_a

        expected_size =
          if limit_value && ids.size > limit_value
            limit_value
          else
            ids.size
          end

        # 11 ids with limit 3, offset 9 should give 2 results.
        if offset_value && (ids.size - offset_value < expected_size)
          expected_size = ids.size - offset_value
        end

        if result.size == expected_size
          result
        else
          raise_record_not_found_exception!(ids, result.size, expected_size)
        end
      end

      def find_some_ordered(ids)
        ids = ids.slice(offset_value || 0, limit_value || ids.size) || []

        result = except(:limit, :offset).where(primary_key => ids).records

        if result.size == ids.size
          result.in_order_of(:id, ids.map { |id| @klass.type_for_attribute(primary_key).cast(id) })
        else
          raise_record_not_found_exception!(ids, result.size, ids.size)
        end
      end

      def find_take
        if loaded?
          records.first
        else
          @take ||= limit(1).records.first
        end
      end

      def find_take_with_limit(limit)
        if loaded?
          records.take(limit)
        else
          limit(limit).to_a
        end
      end

      def find_nth(index)
        @offsets ||= {}
        @offsets[index] ||= find_nth_with_limit(index, 1).first
      end

      def find_nth_with_limit(index, limit)
        if loaded?
          records[index, limit] || []
        else
          relation = ordered_relation

          if limit_value
            limit = [limit_value - index, limit].min
          end

          if limit > 0
            relation = relation.offset((offset_value || 0) + index) unless index.zero?
            relation.limit(limit).to_a
          else
            []
          end
        end
      end

      def find_nth_from_last(index)
        if loaded?
          records[-index]
        else
          relation = ordered_relation

          if relation.order_values.empty? || relation.has_limit_or_offset?
            relation.records[-index]
          else
            relation.reverse_order.offset(index - 1).first
          end
        end
      end

      def find_last(limit)
        limit ? records.last(limit) : records.last
      end

      def ordered_relation
        if order_values.empty? && (implicit_order_column || primary_key)
          if implicit_order_column && primary_key && implicit_order_column != primary_key
            order(table[implicit_order_column].asc, table[primary_key].asc)
          else
            order(table[implicit_order_column || primary_key].asc)
          end
        else
          self
        end
      end
  end
end
