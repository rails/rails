module ActiveRecord
  module FinderMethods
    ONE_AS_ONE = '1 AS one'

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
    # <tt>ActiveRecord::RecordNotFound</tt> will be raised if one or more ids are not found.
    #
    # NOTE: The returned records may not be in the same order as the ids you
    # provide since database rows are unordered. You'd need to provide an explicit <tt>order</tt>
    # option if you want the results are sorted.
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
    # ==== Variations of +find+
    #
    #   Person.where(name: 'Spartacus', rating: 4)
    #   # returns a chainable list (which can be empty).
    #
    #   Person.find_by(name: 'Spartacus', rating: 4)
    #   # returns the first item or nil.
    #
    #   Person.where(name: 'Spartacus', rating: 4).first_or_initialize
    #   # returns the first item or returns a new instance (requires you call .save to persist against the database).
    #
    #   Person.where(name: 'Spartacus', rating: 4).first_or_create
    #   # returns the first item or creates it and returns it, available since Rails 3.2.1.
    #
    # ==== Alternatives for +find+
    #
    #   Person.where(name: 'Spartacus', rating: 4).exists?(conditions = :none)
    #   # returns a boolean indicating if any record with the given conditions exist.
    #
    #   Person.where(name: 'Spartacus', rating: 4).select("field1, field2, field3")
    #   # returns a chainable list of instances with only the mentioned fields.
    #
    #   Person.where(name: 'Spartacus', rating: 4).ids
    #   # returns an Array of ids, available since Rails 3.2.1.
    #
    #   Person.where(name: 'Spartacus', rating: 4).pluck(:field1, :field2)
    #   # returns an Array of the required fields, available since Rails 3.1.
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
    #
    # ==== Rails 3
    #
    #   Person.first # SELECT "people".* FROM "people" LIMIT 1
    #
    # NOTE: Rails 3 may not order this query by the primary key and the order
    # will depend on the database implementation. In order to ensure that behavior,
    # use <tt>User.order(:id).first</tt> instead.
    #
    # ==== Rails 4
    #
    #   Person.first # SELECT "people".* FROM "people" ORDER BY "people"."id" ASC LIMIT 1
    #
    def first(limit = nil)
      if limit
        find_first_with_limit(limit)
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

    # Returns +true+ if a record exists in the table that matches the +id+ or
    # conditions given, or +false+ otherwise. The argument can take six forms:
    #
    # * Integer - Finds the record with this primary key.
    # * String - Finds the record with a primary key corresponding to this
    #   string (such as <tt>'5'</tt>).
    # * Array - Finds the record that matches these +find+-style conditions
    #   (such as <tt>['name LIKE ?', "%#{query}%"]</tt>).
    # * Hash - Finds the record that matches these +find+-style conditions
    #   (such as <tt>{name: 'David'}</tt>).
    # * +false+ - Returns always +false+.
    # * No args - Returns +false+ if the table is empty, +true+ otherwise.
    #
    # For more information about specifying conditions as a hash or array,
    # see the Conditions section in the introduction to <tt>ActiveRecord::Base</tt>.
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

      relation = apply_join_dependency(self, construct_join_dependency)
      return false if ActiveRecord::NullRelation === relation

      relation = relation.except(:select, :order).select(ONE_AS_ONE).limit(1)

      case conditions
      when Array, Hash
        relation = relation.where(conditions)
      else
        relation = relation.where(table[primary_key].eq(conditions)) if conditions != :none
      end

      connection.select_value(relation, "#{name} Exists", relation.bind_values) ? true : false
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

    private

    def find_with_associations
      join_dependency = construct_join_dependency

      aliases  = join_dependency.aliases
      relation = select aliases.columns
      relation = apply_join_dependency(relation, join_dependency)

      if block_given?
        yield relation
      else
        if ActiveRecord::NullRelation === relation
          []
        else
          rows = connection.select_all(relation.arel, 'SQL', relation.bind_values.dup)
          join_dependency.instantiate(rows, aliases)
        end
      end
    end

    def construct_join_dependency(joins = [])
      including = eager_load_values + includes_values
      ActiveRecord::Associations::JoinDependency.new(@klass, including, joins)
    end

    def construct_relation_for_association_calculations
      apply_join_dependency(self, construct_join_dependency(arel.froms.first))
    end

    def apply_join_dependency(relation, join_dependency)
      relation = relation.except(:includes, :eager_load, :preload)
      relation = relation.joins join_dependency

      if using_limitable_reflections?(join_dependency.reflections)
        relation
      else
        if relation.limit_value
          limited_ids = limited_ids_for(relation)
          limited_ids.empty? ? relation.none! : relation.where!(table[primary_key].in(limited_ids))
        end
        relation.except(:limit, :offset)
      end
    end

    def limited_ids_for(relation)
      values = @klass.connection.columns_for_distinct(
        "#{quoted_table_name}.#{quoted_primary_key}", relation.order_values)

      relation = relation.except(:select).select(values).distinct!

      id_rows = @klass.connection.select_all(relation.arel, 'SQL', relation.bind_values)
      id_rows.map {|row| row[primary_key]}
    end

    def using_limitable_reflections?(reflections)
      reflections.none? { |r| r.collection? }
    end

    protected

    def find_with_ids(*ids)
      raise UnknownPrimaryKey.new(@klass) if primary_key.nil?

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
        @first ||= find_first_with_limit(1).first
      end
    end

    def find_first_with_limit(limit)
      if order_values.empty? && primary_key
        order(arel_table[primary_key].asc).limit(limit).to_a
      else
        limit(limit).to_a
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
  end
end
