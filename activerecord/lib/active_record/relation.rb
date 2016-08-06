module ActiveRecord
  # = Active Record \Relation
  class Relation
    MULTI_VALUE_METHODS  = [:includes, :eager_load, :preload, :select, :group,
                            :order, :joins, :left_joins, :left_outer_joins, :references,
                            :extending, :unscope]

    SINGLE_VALUE_METHODS = [:limit, :offset, :lock, :readonly, :reordering,
                            :reverse_order, :distinct, :create_with]
    CLAUSE_METHODS = [:where, :having, :from]
    INVALID_METHODS_FOR_DELETE_ALL = [:limit, :distinct, :offset, :group, :having]

    VALUE_METHODS = MULTI_VALUE_METHODS + SINGLE_VALUE_METHODS + CLAUSE_METHODS

    include Enumerable
    include FinderMethods, Calculations, SpawnMethods, QueryMethods, Batches, Explain, Delegation

    attr_reader :table, :klass, :loaded, :predicate_builder
    alias :model :klass
    alias :loaded? :loaded

    def initialize(klass, table, predicate_builder, values = {})
      @klass  = klass
      @table  = table
      @values = values
      @offsets = {}
      @loaded = false
      @predicate_builder = predicate_builder
    end

    def initialize_copy(other)
      # This method is a hot spot, so for now, use Hash[] to dup the hash.
      #   https://bugs.ruby-lang.org/issues/7166
      @values        = Hash[@values]
      reset
    end

    def insert(values) # :nodoc:
      primary_key_value = nil

      if primary_key && Hash === values
        primary_key_value = values[values.keys.find { |k|
          k.name == primary_key
        }]

        if !primary_key_value && klass.prefetch_primary_key?
          primary_key_value = klass.next_sequence_value
          values[arel_attribute(klass.primary_key)] = primary_key_value
        end
      end

      im = arel.create_insert
      im.into @table

      substitutes, binds = substitute_values values

      if values.empty? # empty insert
        im.values = Arel.sql(connection.empty_insert_statement_value)
      else
        im.insert substitutes
      end

      @klass.connection.insert(
        im,
        "SQL",
        primary_key || false,
        primary_key_value,
        nil,
        binds)
    end

    def _update_record(values, id, id_was) # :nodoc:
      substitutes, binds = substitute_values values

      scope = @klass.unscoped

      if @klass.finder_needs_type_condition?
        scope.unscope!(where: @klass.inheritance_column)
      end

      relation = scope.where(@klass.primary_key => (id_was || id))
      bvs = binds + relation.bound_attributes
      um = relation
        .arel
        .compile_update(substitutes, @klass.primary_key)

      @klass.connection.update(
        um,
        "SQL",
        bvs,
      )
    end

    def substitute_values(values) # :nodoc:
      binds = []
      substitutes = []

      values.each do |arel_attr, value|
        binds.push QueryAttribute.new(arel_attr.name, value, klass.type_for_attribute(arel_attr.name))
        substitutes.push [arel_attr, Arel::Nodes::BindParam.new]
      end

      [substitutes, binds]
    end

    def arel_attribute(name) # :nodoc:
      klass.arel_attribute(name, table)
    end

    # Initializes new record from relation while maintaining the current
    # scope.
    #
    # Expects arguments in the same format as {ActiveRecord::Base.new}[rdoc-ref:Core.new].
    #
    #   users = User.where(name: 'DHH')
    #   user = users.new # => #<User id: nil, name: "DHH", created_at: nil, updated_at: nil>
    #
    # You can also pass a block to new with the new record as argument:
    #
    #   user = users.new { |user| user.name = 'Oscar' }
    #   user.name # => Oscar
    def new(*args, &block)
      scoping { @klass.new(*args, &block) }
    end

    alias build new

    # Tries to create a new record with the same scoped attributes
    # defined in the relation. Returns the initialized object if validation fails.
    #
    # Expects arguments in the same format as
    # {ActiveRecord::Base.create}[rdoc-ref:Persistence::ClassMethods#create].
    #
    # ==== Examples
    #
    #   users = User.where(name: 'Oscar')
    #   users.create # => #<User id: 3, name: "Oscar", ...>
    #
    #   users.create(name: 'fxn')
    #   users.create # => #<User id: 4, name: "fxn", ...>
    #
    #   users.create { |user| user.name = 'tenderlove' }
    #   # => #<User id: 5, name: "tenderlove", ...>
    #
    #   users.create(name: nil) # validation on name
    #   # => #<User id: nil, name: nil, ...>
    def create(*args, &block)
      scoping { @klass.create(*args, &block) }
    end

    # Similar to #create, but calls
    # {create!}[rdoc-ref:Persistence::ClassMethods#create!]
    # on the base class. Raises an exception if a validation error occurs.
    #
    # Expects arguments in the same format as
    # {ActiveRecord::Base.create!}[rdoc-ref:Persistence::ClassMethods#create!].
    def create!(*args, &block)
      scoping { @klass.create!(*args, &block) }
    end

    def first_or_create(attributes = nil, &block) # :nodoc:
      first || create(attributes, &block)
    end

    def first_or_create!(attributes = nil, &block) # :nodoc:
      first || create!(attributes, &block)
    end

    def first_or_initialize(attributes = nil, &block) # :nodoc:
      first || new(attributes, &block)
    end

    # Finds the first record with the given attributes, or creates a record
    # with the attributes if one is not found:
    #
    #   # Find the first user named "Penélope" or create a new one.
    #   User.find_or_create_by(first_name: 'Penélope')
    #   # => #<User id: 1, first_name: "Penélope", last_name: nil>
    #
    #   # Find the first user named "Penélope" or create a new one.
    #   # We already have one so the existing record will be returned.
    #   User.find_or_create_by(first_name: 'Penélope')
    #   # => #<User id: 1, first_name: "Penélope", last_name: nil>
    #
    #   # Find the first user named "Scarlett" or create a new one with
    #   # a particular last name.
    #   User.create_with(last_name: 'Johansson').find_or_create_by(first_name: 'Scarlett')
    #   # => #<User id: 2, first_name: "Scarlett", last_name: "Johansson">
    #
    # This method accepts a block, which is passed down to #create. The last example
    # above can be alternatively written this way:
    #
    #   # Find the first user named "Scarlett" or create a new one with a
    #   # different last name.
    #   User.find_or_create_by(first_name: 'Scarlett') do |user|
    #     user.last_name = 'Johansson'
    #   end
    #   # => #<User id: 2, first_name: "Scarlett", last_name: "Johansson">
    #
    # This method always returns a record, but if creation was attempted and
    # failed due to validation errors it won't be persisted, you get what
    # #create returns in such situation.
    #
    # Please note *this method is not atomic*, it runs first a SELECT, and if
    # there are no results an INSERT is attempted. If there are other threads
    # or processes there is a race condition between both calls and it could
    # be the case that you end up with two similar records.
    #
    # Whether that is a problem or not depends on the logic of the
    # application, but in the particular case in which rows have a UNIQUE
    # constraint an exception may be raised, just retry:
    #
    #  begin
    #    CreditAccount.transaction(requires_new: true) do
    #      CreditAccount.find_or_create_by(user_id: user.id)
    #    end
    #  rescue ActiveRecord::RecordNotUnique
    #    retry
    #  end
    #
    def find_or_create_by(attributes, &block)
      find_by(attributes) || create(attributes, &block)
    end

    # Like #find_or_create_by, but calls
    # {create!}[rdoc-ref:Persistence::ClassMethods#create!] so an exception
    # is raised if the created record is invalid.
    def find_or_create_by!(attributes, &block)
      find_by(attributes) || create!(attributes, &block)
    end

    # Like #find_or_create_by, but calls {new}[rdoc-ref:Core#new]
    # instead of {create}[rdoc-ref:Persistence::ClassMethods#create].
    def find_or_initialize_by(attributes, &block)
      find_by(attributes) || new(attributes, &block)
    end

    # Runs EXPLAIN on the query or queries triggered by this relation and
    # returns the result as a string. The string is formatted imitating the
    # ones printed by the database shell.
    #
    # Note that this method actually runs the queries, since the results of some
    # are needed by the next ones when eager loading is going on.
    #
    # Please see further details in the
    # {Active Record Query Interface guide}[http://guides.rubyonrails.org/active_record_querying.html#running-explain].
    def explain
      #TODO: Fix for binds.
      exec_explain(collecting_queries_for_explain { exec_queries })
    end

    # Converts relation objects to Array.
    def to_a
      records.dup
    end

    def records # :nodoc:
      load
      @records
    end

    # Serializes the relation objects Array.
    def encode_with(coder)
      coder.represent_seq(nil, records)
    end

    def as_json(options = nil) #:nodoc:
      records.as_json(options)
    end

    # Returns size of the records.
    def size
      loaded? ? @records.length : count(:all)
    end

    # Returns true if there are no records.
    def empty?
      return @records.empty? if loaded?

      limit_value == 0 || !exists?
    end

    # Returns true if there are no records.
    def none?
      return super if block_given?
      empty?
    end

    # Returns true if there are any records.
    def any?
      return super if block_given?
      !empty?
    end

    # Returns true if there is exactly one record.
    def one?
      return super if block_given?
      limit_value ? records.one? : size == 1
    end

    # Returns true if there is more than one record.
    def many?
      return super if block_given?
      limit_value ? records.many? : size > 1
    end

    # Returns a cache key that can be used to identify the records fetched by
    # this query. The cache key is built with a fingerprint of the sql query,
    # the number of records matched by the query and a timestamp of the last
    # updated record. When a new record comes to match the query, or any of
    # the existing records is updated or deleted, the cache key changes.
    #
    #   Product.where("name like ?", "%Cosmic Encounter%").cache_key
    #   # => "products/query-1850ab3d302391b85b8693e941286659-1-20150714212553907087000"
    #
    # If the collection is loaded, the method will iterate through the records
    # to generate the timestamp, otherwise it will trigger one SQL query like:
    #
    #    SELECT COUNT(*), MAX("products"."updated_at") FROM "products" WHERE (name like '%Cosmic Encounter%')
    #
    # You can also pass a custom timestamp column to fetch the timestamp of the
    # last updated record.
    #
    #   Product.where("name like ?", "%Game%").cache_key(:last_reviewed_at)
    #
    # You can customize the strategy to generate the key on a per model basis
    # overriding ActiveRecord::Base#collection_cache_key.
    def cache_key(timestamp_column = :updated_at)
      @cache_keys ||= {}
      @cache_keys[timestamp_column] ||= @klass.collection_cache_key(self, timestamp_column)
    end

    # Scope all queries to the current scope.
    #
    #   Comment.where(post_id: 1).scoping do
    #     Comment.first
    #   end
    #   # => SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = 1 ORDER BY "comments"."id" ASC LIMIT 1
    #
    # Please check unscoped if you want to remove all previous scopes (including
    # the default_scope) during the execution of a block.
    def scoping
      previous, klass.current_scope = klass.current_scope, self
      yield
    ensure
      klass.current_scope = previous
    end

    # Updates all records in the current relation with details given. This method constructs a single SQL UPDATE
    # statement and sends it straight to the database. It does not instantiate the involved models and it does not
    # trigger Active Record callbacks or validations. However, values passed to #update_all will still go through
    # Active Record's normal type casting and serialization.
    #
    # ==== Parameters
    #
    # * +updates+ - A string, array, or hash representing the SET part of an SQL statement.
    #
    # ==== Examples
    #
    #   # Update all customers with the given attributes
    #   Customer.update_all wants_email: true
    #
    #   # Update all books with 'Rails' in their title
    #   Book.where('title LIKE ?', '%Rails%').update_all(author: 'David')
    #
    #   # Update all books that match conditions, but limit it to 5 ordered by date
    #   Book.where('title LIKE ?', '%Rails%').order(:created_at).limit(5).update_all(author: 'David')
    def update_all(updates)
      raise ArgumentError, "Empty list of attributes to change" if updates.blank?

      stmt = Arel::UpdateManager.new

      stmt.set Arel.sql(@klass.send(:sanitize_sql_for_assignment, updates))
      stmt.table(table)

      if joins_values.any?
        @klass.connection.join_to_update(stmt, arel, arel_attribute(primary_key))
      else
        stmt.key = arel_attribute(primary_key)
        stmt.take(arel.limit)
        stmt.order(*arel.orders)
        stmt.wheres = arel.constraints
      end

      @klass.connection.update stmt, "SQL", bound_attributes
    end

    # Updates an object (or multiple objects) and saves it to the database, if validations pass.
    # The resulting object is returned whether the object was saved successfully to the database or not.
    #
    # ==== Parameters
    #
    # * +id+ - This should be the id or an array of ids to be updated.
    # * +attributes+ - This should be a hash of attributes or an array of hashes.
    #
    # ==== Examples
    #
    #   # Updates one record
    #   Person.update(15, user_name: 'Samuel', group: 'expert')
    #
    #   # Updates multiple records
    #   people = { 1 => { "first_name" => "David" }, 2 => { "first_name" => "Jeremy" } }
    #   Person.update(people.keys, people.values)
    #
    #   # Updates multiple records from the result of a relation
    #   people = Person.where(group: 'expert')
    #   people.update(group: 'masters')
    #
    # Note: Updating a large number of records will run an
    # UPDATE query for each record, which may cause a performance
    # issue. So if it is not needed to run callbacks for each update, it is
    # preferred to use #update_all for updating all records using
    # a single query.
    def update(id = :all, attributes)
      if id.is_a?(Array)
        id.map.with_index { |one_id, idx| update(one_id, attributes[idx]) }
      elsif id == :all
        records.each { |record| record.update(attributes) }
      else
        if ActiveRecord::Base === id
          id = id.id
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            You are passing an instance of ActiveRecord::Base to `update`.
            Please pass the id of the object by calling `.id`.
          MSG
        end
        object = find(id)
        object.update(attributes)
        object
      end
    end

    # Destroys the records by instantiating each
    # record and calling its {#destroy}[rdoc-ref:Persistence#destroy] method.
    # Each object's callbacks are executed (including <tt>:dependent</tt> association options).
    # Returns the collection of objects that were destroyed; each will be frozen, to
    # reflect that no changes should be made (since they can't be persisted).
    #
    # Note: Instantiation, callback execution, and deletion of each
    # record can be time consuming when you're removing many records at
    # once. It generates at least one SQL +DELETE+ query per record (or
    # possibly more, to enforce your callbacks). If you want to delete many
    # rows quickly, without concern for their associations or callbacks, use
    # #delete_all instead.
    #
    # ==== Examples
    #
    #   Person.where(age: 0..18).destroy_all
    def destroy_all(conditions = nil)
      if conditions
        ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
          Passing conditions to destroy_all is deprecated and will be removed in Rails 5.1.
          To achieve the same use where(conditions).destroy_all.
        MESSAGE
        where(conditions).destroy_all
      else
        records.each(&:destroy).tap { reset }
      end
    end

    # Destroy an object (or multiple objects) that has the given id. The object is instantiated first,
    # therefore all callbacks and filters are fired off before the object is deleted. This method is
    # less efficient than #delete but allows cleanup methods and other actions to be run.
    #
    # This essentially finds the object (or multiple objects) with the given id, creates a new object
    # from the attributes, and then calls destroy on it.
    #
    # ==== Parameters
    #
    # * +id+ - Can be either an Integer or an Array of Integers.
    #
    # ==== Examples
    #
    #   # Destroy a single object
    #   Todo.destroy(1)
    #
    #   # Destroy multiple objects
    #   todos = [1,2,3]
    #   Todo.destroy(todos)
    def destroy(id)
      if id.is_a?(Array)
        id.map { |one_id| destroy(one_id) }
      else
        find(id).destroy
      end
    end

    # Deletes the records without instantiating the records
    # first, and hence not calling the {#destroy}[rdoc-ref:Persistence#destroy]
    # method nor invoking callbacks.
    # This is a single SQL DELETE statement that goes straight to the database, much more
    # efficient than #destroy_all. Be careful with relations though, in particular
    # <tt>:dependent</tt> rules defined on associations are not honored. Returns the
    # number of rows affected.
    #
    #   Post.where(person_id: 5).where(category: ['Something', 'Else']).delete_all
    #
    # Both calls delete the affected posts all at once with a single DELETE statement.
    # If you need to destroy dependent associations or call your <tt>before_*</tt> or
    # +after_destroy+ callbacks, use the #destroy_all method instead.
    #
    # If an invalid method is supplied, #delete_all raises an ActiveRecordError:
    #
    #   Post.limit(100).delete_all
    #   # => ActiveRecord::ActiveRecordError: delete_all doesn't support limit
    def delete_all(conditions = nil)
      invalid_methods = INVALID_METHODS_FOR_DELETE_ALL.select { |method|
        if MULTI_VALUE_METHODS.include?(method)
          send("#{method}_values").any?
        elsif SINGLE_VALUE_METHODS.include?(method)
          send("#{method}_value")
        elsif CLAUSE_METHODS.include?(method)
          send("#{method}_clause").any?
        end
      }
      if invalid_methods.any?
        raise ActiveRecordError.new("delete_all doesn't support #{invalid_methods.join(', ')}")
      end

      if conditions
        ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
          Passing conditions to delete_all is deprecated and will be removed in Rails 5.1.
          To achieve the same use where(conditions).delete_all.
        MESSAGE
        where(conditions).delete_all
      else
        stmt = Arel::DeleteManager.new
        stmt.from(table)

        if joins_values.any?
          @klass.connection.join_to_delete(stmt, arel, arel_attribute(primary_key))
        else
          stmt.wheres = arel.constraints
        end

        affected = @klass.connection.delete(stmt, "SQL", bound_attributes)

        reset
        affected
      end
    end

    # Deletes the row with a primary key matching the +id+ argument, using a
    # SQL +DELETE+ statement, and returns the number of rows deleted. Active
    # Record objects are not instantiated, so the object's callbacks are not
    # executed, including any <tt>:dependent</tt> association options.
    #
    # You can delete multiple rows at once by passing an Array of <tt>id</tt>s.
    #
    # Note: Although it is often much faster than the alternative,
    # #destroy, skipping callbacks might bypass business logic in
    # your application that ensures referential integrity or performs other
    # essential jobs.
    #
    # ==== Examples
    #
    #   # Delete a single row
    #   Todo.delete(1)
    #
    #   # Delete multiple rows
    #   Todo.delete([2,3,4])
    def delete(id_or_array)
      where(primary_key => id_or_array).delete_all
    end

    # Causes the records to be loaded from the database if they have not
    # been loaded already. You can use this if for some reason you need
    # to explicitly load some records before actually using them. The
    # return value is the relation itself, not the records.
    #
    #   Post.where(published: true).load # => #<ActiveRecord::Relation>
    def load
      exec_queries unless loaded?

      self
    end

    # Forces reloading of relation.
    def reload
      reset
      load
    end

    def reset
      @last = @to_sql = @order_clause = @scope_for_create = @arel = @loaded = nil
      @should_eager_load = @join_dependency = nil
      @records = [].freeze
      @offsets = {}
      self
    end

    # Returns sql statement for the relation.
    #
    #   User.where(name: 'Oscar').to_sql
    #   # => SELECT "users".* FROM "users"  WHERE "users"."name" = 'Oscar'
    def to_sql
      @to_sql ||= begin
                    relation = self

                    if eager_loading?
                      find_with_associations { |rel| relation = rel }
                    end

                    conn = klass.connection
                    conn.unprepared_statement {
                      conn.to_sql(relation.arel, relation.bound_attributes)
                    }
                  end
    end

    # Returns a hash of where conditions.
    #
    #   User.where(name: 'Oscar').where_values_hash
    #   # => {name: "Oscar"}
    def where_values_hash(relation_table_name = table_name)
      where_clause.to_h(relation_table_name)
    end

    def scope_for_create
      @scope_for_create ||= where_values_hash.merge(create_with_value)
    end

    # Returns true if relation needs eager loading.
    def eager_loading?
      @should_eager_load ||=
        eager_load_values.any? ||
        includes_values.any? && (joined_includes_values.any? || references_eager_loaded_tables?)
    end

    # Joins that are also marked for preloading. In which case we should just eager load them.
    # Note that this is a naive implementation because we could have strings and symbols which
    # represent the same association, but that aren't matched by this. Also, we could have
    # nested hashes which partially match, e.g. { a: :b } & { a: [:b, :c] }
    def joined_includes_values
      includes_values & joins_values
    end

    # {#uniq}[rdoc-ref:QueryMethods#uniq] and
    # {#uniq!}[rdoc-ref:QueryMethods#uniq!] are silently deprecated.
    # #uniq_value delegates to #distinct_value to maintain backwards compatibility.
    # Use #distinct_value instead.
    def uniq_value
      distinct_value
    end
    deprecate uniq_value: :distinct_value

    # Compares two relations for equality.
    def ==(other)
      case other
      when Associations::CollectionProxy, AssociationRelation
        self == other.records
      when Relation
        other.to_sql == to_sql
      when Array
        records == other
      end
    end

    def pretty_print(q)
      q.pp(self.records)
    end

    # Returns true if relation is blank.
    def blank?
      records.blank?
    end

    def values
      Hash[@values]
    end

    def inspect
      entries = records.take([limit_value, 11].compact.min).map!(&:inspect)
      entries[10] = "..." if entries.size == 11

      "#<#{self.class.name} [#{entries.join(', ')}]>"
    end

    protected

      def load_records(records)
        @records = records.freeze
        @loaded = true
      end

    private

      def exec_queries
        @records = eager_loading? ? find_with_associations.freeze : @klass.find_by_sql(arel, bound_attributes).freeze

        preload = preload_values
        preload +=  includes_values unless eager_loading?
        preloader = build_preloader
        preload.each do |associations|
          preloader.preload @records, associations
        end

        @records.each(&:readonly!) if readonly_value

        @loaded = true
        @records
      end

      def build_preloader
        ActiveRecord::Associations::Preloader.new
      end

      def references_eager_loaded_tables?
        joined_tables = arel.join_sources.map do |join|
          if join.is_a?(Arel::Nodes::StringJoin)
            tables_in_string(join.left)
          else
            [join.left.table_name, join.left.table_alias]
          end
        end

        joined_tables += [table.name, table.table_alias]

        # always convert table names to downcase as in Oracle quoted table names are in uppercase
        joined_tables = joined_tables.flatten.compact.map(&:downcase).uniq

        (references_values - joined_tables).any?
      end

      def tables_in_string(string)
        return [] if string.blank?
        # always convert table names to downcase as in Oracle quoted table names are in uppercase
        # ignore raw_sql_ that is used by Oracle adapter as alias for limit/offset subqueries
        string.scan(/([a-zA-Z_][.\w]+).?\./).flatten.map(&:downcase).uniq - ["raw_sql_"]
      end
  end
end
