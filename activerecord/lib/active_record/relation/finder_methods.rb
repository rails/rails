require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/indifferent_access'

module ActiveRecord
  module FinderMethods
    # Find operates with four different retrieval approaches:
    #
    # * Find by id - This can either be a specific id (1), a list of ids (1, 5, 6), or an array of ids ([5, 6, 10]).
    #   If no record can be found for all of the listed ids, then RecordNotFound will be raised.
    # * Find first - This will return the first record matched by the options used. These options can either be specific
    #   conditions or merely an order. If no record can be matched, +nil+ is returned. Use
    #   <tt>Model.find(:first, *args)</tt> or its shortcut <tt>Model.first(*args)</tt>.
    # * Find last - This will return the last record matched by the options used. These options can either be specific
    #   conditions or merely an order. If no record can be matched, +nil+ is returned. Use
    #   <tt>Model.find(:last, *args)</tt> or its shortcut <tt>Model.last(*args)</tt>.
    # * Find all - This will return all the records matched by the options used.
    #   If no records are found, an empty array is returned. Use
    #   <tt>Model.find(:all, *args)</tt> or its shortcut <tt>Model.all(*args)</tt>.
    #
    # All approaches accept an options hash as their last parameter.
    #
    # ==== Options
    #
    # * <tt>:conditions</tt> - An SQL fragment like "administrator = 1", <tt>["user_name = ?", username]</tt>,
    #   or <tt>["user_name = :user_name", { :user_name => user_name }]</tt>. See conditions in the intro.
    # * <tt>:order</tt> - An SQL fragment like "created_at DESC, name".
    # * <tt>:group</tt> - An attribute name by which the result should be grouped. Uses the <tt>GROUP BY</tt> SQL-clause.
    # * <tt>:having</tt> - Combined with +:group+ this can be used to filter the records that a
    #   <tt>GROUP BY</tt> returns. Uses the <tt>HAVING</tt> SQL-clause.
    # * <tt>:limit</tt> - An integer determining the limit on the number of rows that should be returned.
    # * <tt>:offset</tt> - An integer determining the offset from where the rows should be fetched. So at 5,
    #   it would skip rows 0 through 4.
    # * <tt>:joins</tt> - Either an SQL fragment for additional joins like "LEFT JOIN comments ON comments.post_id = id" (rarely needed),
    #   named associations in the same form used for the <tt>:include</tt> option, which will perform an
    #   <tt>INNER JOIN</tt> on the associated table(s),
    #   or an array containing a mixture of both strings and named associations.
    #   If the value is a string, then the records will be returned read-only since they will
    #   have attributes that do not correspond to the table's columns.
    #   Pass <tt>:readonly => false</tt> to override.
    # * <tt>:include</tt> - Names associations that should be loaded alongside. The symbols named refer
    #   to already defined associations. See eager loading under Associations.
    # * <tt>:select</tt> - By default, this is "*" as in "SELECT * FROM", but can be changed if you,
    #   for example, want to do a join but not include the joined columns. Takes a string with the SELECT SQL fragment (e.g. "id, name").
    # * <tt>:from</tt> - By default, this is the table name of the class, but can be changed
    #   to an alternate table name (or even the name of a database view).
    # * <tt>:readonly</tt> - Mark the returned records read-only so they cannot be saved or updated.
    # * <tt>:lock</tt> - An SQL fragment like "FOR UPDATE" or "LOCK IN SHARE MODE".
    #   <tt>:lock => true</tt> gives connection's default exclusive lock, usually "FOR UPDATE".
    #
    # ==== Examples
    #
    #   # find by id
    #   Person.find(1)       # returns the object for ID = 1
    #   Person.find(1, 2, 6) # returns an array for objects with IDs in (1, 2, 6)
    #   Person.find([7, 17]) # returns an array for objects with IDs in (7, 17)
    #   Person.find([1])     # returns an array for the object with ID = 1
    #   Person.where("administrator = 1").order("created_on DESC").find(1)
    #
    # Note that returned records may not be in the same order as the ids you
    # provide since database rows are unordered. Give an explicit <tt>:order</tt>
    # to ensure the results are sorted.
    #
    # ==== Examples
    #
    #   # find first
    #   Person.first # returns the first object fetched by SELECT * FROM people
    #   Person.where(["user_name = ?", user_name]).first
    #   Person.where(["user_name = :u", { :u => user_name }]).first
    #   Person.order("created_on DESC").offset(5).first
    #
    #   # find last
    #   Person.last # returns the last object fetched by SELECT * FROM people
    #   Person.where(["user_name = ?", user_name]).last
    #   Person.order("created_on DESC").offset(5).last
    #
    #   # find all
    #   Person.all # returns an array of objects for all the rows fetched by SELECT * FROM people
    #   Person.where(["category IN (?)", categories]).limit(50).all
    #   Person.where({ :friends => ["Bob", "Steve", "Fred"] }).all
    #   Person.offset(10).limit(10).all
    #   Person.includes([:account, :friends]).all
    #   Person.group("category").all
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
      return to_a.find { |*block_args| yield(*block_args) } if block_given?

      options = args.extract_options!

      if options.present?
        apply_finder_options(options).find(*args)
      else
        case args.first
        when :first, :last, :all
          send(args.first)
        else
          find_with_ids(*args)
        end
      end
    end

    # A convenience wrapper for <tt>find(:first, *args)</tt>. You can pass in all the
    # same arguments to this method as you can to <tt>find(:first)</tt>.
    def first(*args)
      if args.any?
        if args.first.kind_of?(Integer) || (loaded? && !args.first.kind_of?(Hash))
          limit(*args).to_a
        else
          apply_finder_options(args.first).first
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

    # A convenience wrapper for <tt>find(:last, *args)</tt>. You can pass in all the
    # same arguments to this method as you can to <tt>find(:last)</tt>.
    def last(*args)
      if args.any?
        if args.first.kind_of?(Integer) || (loaded? && !args.first.kind_of?(Hash))
          if order_values.empty?
            order("#{primary_key} DESC").limit(*args).reverse
          else
            to_a.last(*args)
          end
        else
          apply_finder_options(args.first).last
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

    # A convenience wrapper for <tt>find(:all, *args)</tt>. You can pass in all the
    # same arguments to this method as you can to <tt>find(:all)</tt>.
    def all(*args)
      args.any? ? apply_finder_options(args.first).to_a : to_a
    end

    # Returns true if a record exists in the table that matches the +id+ or
    # conditions given, or false otherwise. The argument can take five forms:
    #
    # * Integer - Finds the record with this primary key.
    # * String - Finds the record with a primary key corresponding to this
    #   string (such as <tt>'5'</tt>).
    # * Array - Finds the record that matches these +find+-style conditions
    #   (such as <tt>['color = ?', 'red']</tt>).
    # * Hash - Finds the record that matches these +find+-style conditions
    #   (such as <tt>{:color => 'red'}</tt>).
    # * No args - Returns false if the table is empty, true otherwise.
    #
    # For more information about specifying conditions as a Hash or Array,
    # see the Conditions section in the introduction to ActiveRecord::Base.
    #
    # Note: You can't pass in a condition as a string (like <tt>name =
    # 'Jamie'</tt>), since it would be sanitized and then queried against
    # the primary key column, like <tt>id = 'name = \'Jamie\''</tt>.
    #
    # ==== Examples
    #   Person.exists?(5)
    #   Person.exists?('5')
    #   Person.exists?(:name => "David")
    #   Person.exists?(['name LIKE ?', "%#{query}%"])
    #   Person.exists?
    def exists?(id = false)
      return false if id.nil?

      id = id.id if ActiveRecord::Base === id

      join_dependency = construct_join_dependency_for_association_find
      relation = construct_relation_for_association_find(join_dependency)
      relation = relation.except(:select, :order).select("1").limit(1)

      case id
      when Array, Hash
        relation = relation.where(id)
      else
        relation = relation.where(table[primary_key].eq(id)) if id
      end

      connection.select_value(relation, "#{name} Exists") ? true : false
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
      including = (@eager_load_values + @includes_values).uniq
      ActiveRecord::Associations::JoinDependency.new(@klass, including, [])
    end

    def construct_relation_for_association_calculations
      including = (@eager_load_values + @includes_values).uniq
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
      values = @klass.connection.distinct("#{@klass.connection.quote_table_name table_name}.#{primary_key}", orders)

      relation = relation.dup

      ids_array = relation.select(values).collect {|row| row[primary_key]}
      ids_array.empty? ? raise(ThrowResult) : table[primary_key].in(ids_array)
    end

    def find_by_attributes(match, attributes, *args)
      conditions = Hash[attributes.map {|a| [a, args[attributes.index(a)]]}]
      result = where(conditions).send(match.finder)

      if match.bang? && result.blank?
        raise RecordNotFound, "Couldn't find #{@klass.name} with #{conditions.to_a.collect {|p| p.join(' = ')}.join(', ')}"
      else
        yield(result) if block_given?
        result
      end
    end

    def find_or_instantiator_by_attributes(match, attributes, *args)
      options = args.size > 1 && args.last(2).all?{ |a| a.is_a?(Hash) } ? args.extract_options! : {}
      protected_attributes_for_create, unprotected_attributes_for_create = {}, {}
      args.each_with_index do |arg, i|
        if arg.is_a?(Hash)
          protected_attributes_for_create = args[i].with_indifferent_access
        else
          unprotected_attributes_for_create[attributes[i]] = args[i]
        end
      end

      conditions = (protected_attributes_for_create.merge(unprotected_attributes_for_create)).slice(*attributes).symbolize_keys

      record = where(conditions).first

      unless record
        record = @klass.new(protected_attributes_for_create, options) do |r|
          r.assign_attributes(unprotected_attributes_for_create, :without_protection => true)
        end
        yield(record) if block_given?
        record.send(match.save_method) if match.save_record?
      end

      record
    end

    def find_with_ids(*ids)
      return to_a.find { |*block_args| yield(*block_args) } if block_given?

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

      if IdentityMap.enabled? && where_values.blank? &&
        limit_value.blank? && order_values.blank? &&
        includes_values.blank? && preload_values.blank? &&
        readonly_value.nil? && joins_values.blank? &&
        !@klass.locking_enabled? &&
        record = IdentityMap.get(@klass, id)
        return record
      end

      column = columns_hash[primary_key]

      substitute = connection.substitute_at(column, @bind_values.length)
      relation = where(table[primary_key].eq(substitute))
      relation.bind_values = [[column, id]]
      record = relation.first

      unless record
        conditions = arel.where_sql
        conditions = " [#{conditions}]" if conditions
        raise RecordNotFound, "Couldn't find #{@klass.name} with #{primary_key}=#{id}#{conditions}"
      end

      record
    end

    def find_some(ids)
      result = where(table[primary_key].in(ids)).all

      expected_size =
        if @limit_value && ids.size > @limit_value
          @limit_value
        else
          ids.size
        end

      # 11 ids with limit 3, offset 9 should give 2 results.
      if @offset_value && (ids.size - @offset_value < expected_size)
        expected_size = ids.size - @offset_value
      end

      if result.size == expected_size
        result
      else
        conditions = arel.where_sql
        conditions = " [#{conditions}]" if conditions

        error = "Couldn't find all #{@klass.name.pluralize} with IDs "
        error << "(#{ids.join(", ")})#{conditions} (found #{result.size} results, but was looking for #{expected_size})"
        raise RecordNotFound, error
      end
    end

    def find_first
      if loaded?
        @records.first
      else
        @first ||= limit(1).to_a[0]
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
            reverse_order.limit(1).to_a[0]
          end
      end
    end

    def using_limitable_reflections?(reflections)
      reflections.none? { |r| r.collection? }
    end
  end
end
