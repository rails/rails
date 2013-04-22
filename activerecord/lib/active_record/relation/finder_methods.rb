module ActiveRecord
  module FinderMethods
    # Find by id - This can either be a specific id (1), a list of ids (1, 5, 6), or an array of ids ([5, 6, 10]).
    # If no record can be found for all of the listed ids, then RecordNotFound will be raised. If the primary key
    # is an integer, find by id coerces its arguments using +to_i+.
    #
    #   Person.find(1)       # returns the object for ID = 1
    #   Person.find("1")     # returns the object for ID = 1
    #   Person.find(1, 2, 6) # returns an array for objects with IDs in (1, 2, 6)
    #   Person.find([7, 17]) # returns an array for objects with IDs in (7, 17)
    #   Person.find([1])     # returns an array for the object with ID = 1
    #   Person.where("administrator = 1").order("created_on DESC").find(1)
    #
    # Note that returned records may not be in the same order as the ids you
    # provide since database rows are unordered. Give an explicit <tt>order</tt>
    # to ensure the results are sorted.
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
    def find(*args)
      if block_given?
        to_a.find { |*block_args| yield(*block_args) }
      else
        find_with_ids(*args)
      end
    end

    # Finds the first record matching the specified conditions. There
    # is no implied ordering so if order matters, you should specify it
    # yourself.
    #
    # If no record is found, returns <tt>nil</tt>.
    #
    #   Post.find_by name: 'Spartacus', rating: 4
    #   Post.find_by "published_at < ?", 2.weeks.ago
    def find_by(*args)
      where(*args).take
    end

    # Like <tt>find_by</tt>, except that if no record is found, raises
    # an <tt>ActiveRecord::RecordNotFound</tt> error.
    def find_by!(*args)
      where(*args).take!
    end

    # Gives a record (or N records if a parameter is supplied) without any implied
    # order. The order will depend on the database implementation.
    # If an order is supplied it will be respected.
    #
    #   Person.take # returns an object fetched by SELECT * FROM people LIMIT 1
    #   Person.take(5) # returns 5 objects fetched by SELECT * FROM people LIMIT 5
    #   Person.where(["name LIKE '%?'", name]).take
    def take(limit = nil)
      limit ? limit(limit).to_a : find_take
    end

    # Same as +take+ but raises <tt>ActiveRecord::RecordNotFound</tt> if no record
    # is found. Note that <tt>take!</tt> accepts no arguments.
    def take!
      take or raise RecordNotFound
    end

    # Find the first record (or first N records if a parameter is supplied).
    # If no order is defined it will order by primary key.
    #
    #   Person.first # returns the first object fetched by SELECT * FROM people
    #   Person.where(["user_name = ?", user_name]).first
    #   Person.where(["user_name = :u", { u: user_name }]).first
    #   Person.order("created_on DESC").offset(5).first
    #   Person.first(3) # returns the first three objects fetched by SELECT * FROM people LIMIT 3
    def first(limit = nil)
      if limit
        if order_values.empty? && primary_key
          order(arel_table[primary_key].asc).limit(limit).to_a
        else
          limit(limit).to_a
        end
      else
        find_first
      end
    end

    # Same as +first+ but raises <tt>ActiveRecord::RecordNotFound</tt> if no record
    # is found. Note that <tt>first!</tt> accepts no arguments.
    def first!
      first or raise RecordNotFound
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
      if limit
        if order_values.empty? && primary_key
          order(arel_table[primary_key].desc).limit(limit).reverse
        else
          to_a.last(limit)
        end
      else
        find_last
      end
    end

    # Same as +last+ but raises <tt>ActiveRecord::RecordNotFound</tt> if no record
    # is found. Note that <tt>last!</tt> accepts no arguments.
    def last!
      last or raise RecordNotFound
    end

    # Returns truthy if a record exists in the table that matches the +id+ or
    # conditions given, or falsy otherwise. The argument can take six forms:
    #
    # * Integer - Finds the record with this primary key.
    # * String - Finds the record with a primary key corresponding to this
    #   string (such as <tt>'5'</tt>).
    # * Array - Finds the record that matches these +find+-style conditions
    #   (such as <tt>['color = ?', 'red']</tt>).
    # * Hash - Finds the record that matches these +find+-style conditions
    #   (such as <tt>{color: 'red'}</tt>).
    # * +false+ - Returns always +false+.
    # * No args - Returns +false+ if the table is empty, +true+ otherwise.
    #
    # For more information about specifying conditions as a Hash or Array,
    # see the Conditions section in the introduction to ActiveRecord::Base.
    #
    # Note: You can't pass in a condition as a string (like <tt>name =
    # 'Jamie'</tt>), since it would be sanitized and then queried against
    # the primary key column, like <tt>id = 'name = \'Jamie\''</tt>.
    #
    #   Person.exists?(5)
    #   Person.exists?('5')
    #   Person.exists?(['name LIKE ?', "%#{query}%"])
    #   Person.exists?(name: 'David')
    #   Person.exists?(false)
    #   Person.exists?
    def exists?(conditions = :none)
      conditions = conditions.id if Base === conditions
      return false if !conditions

      join_dependency = construct_join_dependency_for_association_find
      relation = construct_relation_for_association_find(join_dependency)
      relation = relation.except(:select, :order).select("1 AS one").limit(1)

      case conditions
      when Array, Hash
        relation = relation.where(conditions)
      else
        relation = relation.where(table[primary_key].eq(conditions)) if conditions != :none
      end

      connection.select_value(relation, "#{name} Exists", relation.bind_values)
    rescue ThrowResult
      false
    end

    # This method is called whenever no records are found with either a single
    # id or multiple ids and raises a +ActiveRecord::RecordNotFound+ exception.
    #
    # The error message is different depending on whether a single id or
    # multiple ids are provided. If multiple ids are provided, then the number
    # of results obtained should be provided in the +result_size+ argument and
    # the expected number of results should be provided in the +expected_size+
    # argument.
    def raise_record_not_found_exception!(ids, result_size, expected_size) #:nodoc:
      conditions = arel.where_sql
      conditions = " [#{conditions}]" if conditions

      if Array(ids).size == 1
        error = "Couldn't find #{@klass.name} with #{primary_key}=#{ids}#{conditions}"
      else
        error = "Couldn't find all #{@klass.name.pluralize} with IDs "
        error << "(#{ids.join(", ")})#{conditions} (found #{result_size} results, but was looking for #{expected_size})"
      end

      raise RecordNotFound, error
    end

    protected

    def find_with_associations
      join_dependency = construct_join_dependency_for_association_find
      relation = construct_relation_for_association_find(join_dependency)
      rows = connection.select_all(relation, 'SQL', relation.bind_values.dup)
      join_dependency.instantiate(rows)
    rescue ThrowResult
      []
    end

    def construct_join_dependency_for_association_find
      including = (eager_load_values + includes_values).uniq
      ActiveRecord::Associations::JoinDependency.new(@klass, including, [])
    end

    def construct_relation_for_association_calculations
      including = (eager_load_values + includes_values).uniq
      join_dependency = ActiveRecord::Associations::JoinDependency.new(@klass, including, arel.froms.first)
      relation = except(:includes, :eager_load, :preload)
      apply_join_dependency(relation, join_dependency)
    end

    def construct_relation_for_association_find(join_dependency)
      relation = except(:includes, :eager_load, :preload, :select).select(join_dependency.columns)
      apply_join_dependency(relation, join_dependency)
    end

    def apply_join_dependency(relation, join_dependency)
      join_dependency.join_associations.each do |association|
        relation = association.join_relation(relation)
      end

      limitable_reflections = using_limitable_reflections?(join_dependency.reflections)

      if !limitable_reflections && relation.limit_value
        limited_id_condition = construct_limited_ids_condition(relation.except(:select))
        relation = relation.where(limited_id_condition)
      end

      relation = relation.except(:limit, :offset) unless limitable_reflections

      relation
    end

    def construct_limited_ids_condition(relation)
      orders = relation.order_values.map { |val| val.presence }.compact
      values = @klass.connection.distinct("#{quoted_table_name}.#{primary_key}", orders)

      relation = relation.dup.select(values)

      id_rows = @klass.connection.select_all(relation.arel, 'SQL', relation.bind_values)
      ids_array = id_rows.map {|row| row[primary_key]}

      ids_array.empty? ? raise(ThrowResult) : table[primary_key].in(ids_array)
    end

    def find_with_ids(*ids)
      expects_array = ids.first.kind_of?(Array)
      return ids.first if expects_array && ids.first.empty?

      ids = ids.flatten.compact.uniq

      case ids.size
      when 0
        raise RecordNotFound, "Couldn't find #{@klass.name} without an ID"
      when 1
        result = find_one(ids.first)
        expects_array ? [ result ] : result
      else
        find_some(ids)
      end
    end

    def find_one(id)
      id = id.id if ActiveRecord::Base === id

      column = columns_hash[primary_key]
      substitute = connection.substitute_at(column, bind_values.length)
      relation = where(table[primary_key].eq(substitute))
      relation.bind_values += [[column, id]]
      record = relation.take

      raise_record_not_found_exception!(id, 0, 1) unless record

      record
    end

    def find_some(ids)
      result = where(table[primary_key].in(ids)).to_a

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

    def find_take
      if loaded?
        @records.first
      else
        @take ||= limit(1).to_a.first
      end
    end

    def find_first
      if loaded?
        @records.first
      else
        @first ||=
          if with_default_scope.order_values.empty? && primary_key
            order(arel_table[primary_key].asc).limit(1).to_a.first
          else
            limit(1).to_a.first
          end
      end
    end

    def find_last
      if loaded?
        @records.last
      else
        @last ||=
          if offset_value || limit_value
            to_a.last
          else
            reverse_order.limit(1).to_a.first
          end
      end
    end

    def using_limitable_reflections?(reflections)
      reflections.none? { |r| r.collection? }
    end
  end
end
