# frozen_string_literal: true

module ActiveRecord
  # = Active Record \Relation
  class Relation
    MULTI_VALUE_METHODS  = [:includes, :eager_load, :preload, :select, :group,
                            :order, :joins, :left_outer_joins, :references,
                            :extending, :unscope]

    SINGLE_VALUE_METHODS = [:limit, :offset, :lock, :readonly, :reordering,
                            :reverse_order, :distinct, :create_with, :skip_query_cache]

    CLAUSE_METHODS = [:where, :having, :from]
    INVALID_METHODS_FOR_DELETE_ALL = [:distinct, :group, :having]

    VALUE_METHODS = MULTI_VALUE_METHODS + SINGLE_VALUE_METHODS + CLAUSE_METHODS

    include Enumerable
    include FinderMethods, Calculations, SpawnMethods, QueryMethods, Batches, Explain, Delegation

    attr_reader :table, :klass, :loaded, :predicate_builder
    attr_accessor :skip_preloading_value
    alias :model :klass
    alias :loaded? :loaded
    alias :locked? :lock_value

    def initialize(klass, table: klass.arel_table, predicate_builder: klass.predicate_builder, values: {})
      @klass  = klass
      @table  = table
      @values = values
      @offsets = {}
      @loaded = false
      @predicate_builder = predicate_builder
      @delegate_to_klass = false
    end

    def initialize_copy(_other)
      @values = @values.dup
      reset
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
    def new(attributes = nil, &block)
      scoping { klass.new(scope_for_create(attributes), &block) }
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
    def create(attributes = nil, &block)
      if attributes.is_a?(Array)
        attributes.collect { |attr| create(attr, &block) }
      else
        scoping { klass.create(scope_for_create(attributes), &block) }
      end
    end

    # Similar to #create, but calls
    # {create!}[rdoc-ref:Persistence::ClassMethods#create!]
    # on the base class. Raises an exception if a validation error occurs.
    #
    # Expects arguments in the same format as
    # {ActiveRecord::Base.create!}[rdoc-ref:Persistence::ClassMethods#create!].
    def create!(attributes = nil, &block)
      if attributes.is_a?(Array)
        attributes.collect { |attr| create!(attr, &block) }
      else
        scoping { klass.create!(scope_for_create(attributes), &block) }
      end
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
    # Please note <b>this method is not atomic</b>, it runs first a SELECT, and if
    # there are no results an INSERT is attempted. If there are other threads
    # or processes there is a race condition between both calls and it could
    # be the case that you end up with two similar records.
    #
    # If this might be a problem for your application, please see #create_or_find_by.
    def find_or_create_by(attributes, &block)
      find_by(attributes) || create(attributes, &block)
    end

    # Like #find_or_create_by, but calls
    # {create!}[rdoc-ref:Persistence::ClassMethods#create!] so an exception
    # is raised if the created record is invalid.
    def find_or_create_by!(attributes, &block)
      find_by(attributes) || create!(attributes, &block)
    end

    # Attempts to create a record with the given attributes in a table that has a unique constraint
    # on one or several of its columns. If a row already exists with one or several of these
    # unique constraints, the exception such an insertion would normally raise is caught,
    # and the existing record with those attributes is found using #find_by.
    #
    # This is similar to #find_or_create_by, but avoids the problem of stale reads between the SELECT
    # and the INSERT, as that method needs to first query the table, then attempt to insert a row
    # if none is found.
    #
    # There are several drawbacks to #create_or_find_by, though:
    #
    # * The underlying table must have the relevant columns defined with unique constraints.
    # * A unique constraint violation may be triggered by only one, or at least less than all,
    #   of the given attributes. This means that the subsequent #find_by may fail to find a
    #   matching record, which will then raise an <tt>ActiveRecord::RecordNotFound</tt> exception,
    #   rather than a record with the given attributes.
    # * While we avoid the race condition between SELECT -> INSERT from #find_or_create_by,
    #   we actually have another race condition between INSERT -> SELECT, which can be triggered
    #   if a DELETE between those two statements is run by another client. But for most applications,
    #   that's a significantly less likely condition to hit.
    # * It relies on exception handling to handle control flow, which may be marginally slower.
    #
    # This method will return a record if all given attributes are covered by unique constraints
    # (unless the INSERT -> DELETE -> SELECT race condition is triggered), but if creation was attempted
    # and failed due to validation errors it won't be persisted, you get what #create returns in
    # such situation.
    def create_or_find_by(attributes, &block)
      transaction(requires_new: true) { create(attributes, &block) }
    rescue ActiveRecord::RecordNotUnique
      find_by!(attributes)
    end

    # Like #create_or_find_by, but calls
    # {create!}[rdoc-ref:Persistence::ClassMethods#create!] so an exception
    # is raised if the created record is invalid.
    def create_or_find_by!(attributes, &block)
      transaction(requires_new: true) { create!(attributes, &block) }
    rescue ActiveRecord::RecordNotUnique
      find_by!(attributes)
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
      exec_explain(collecting_queries_for_explain { exec_queries })
    end

    # Converts relation objects to Array.
    def to_ary
      records.dup
    end
    alias to_a to_ary

    def records # :nodoc:
      load
      @records
    end

    # Serializes the relation objects Array.
    def encode_with(coder)
      coder.represent_seq(nil, records)
    end

    # Returns size of the records.
    def size
      loaded? ? @records.length : count(:all)
    end

    # Returns true if there are no records.
    def empty?
      return @records.empty? if loaded?
      !exists?
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
      previous, klass.current_scope = klass.current_scope(true), self
      yield
    ensure
      klass.current_scope = previous
    end

    def _exec_scope(*args, &block) # :nodoc:
      @delegate_to_klass = true
      instance_exec(*args, &block) || self
    ensure
      @delegate_to_klass = false
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
    #
    #   # Update all invoices and set the number column to its id value.
    #   Invoice.update_all('number = id')
    def update_all(updates)
      raise ArgumentError, "Empty list of attributes to change" if updates.blank?

      if eager_loading?
        relation = apply_join_dependency
        return relation.update_all(updates)
      end

      stmt = Arel::UpdateManager.new

      stmt.set Arel.sql(@klass.sanitize_sql_for_assignment(updates))
      stmt.table(table)

      if has_join_values? || offset_value
        @klass.connection.join_to_update(stmt, arel, arel_attribute(primary_key))
      else
        stmt.key = arel_attribute(primary_key)
        stmt.take(arel.limit)
        stmt.order(*arel.orders)
        stmt.wheres = arel.constraints
      end

      @klass.connection.update stmt, "#{@klass} Update All"
    end

    # Touches all records in the current relation without instantiating records first with the updated_at/on attributes
    # set to the current time or the time specified.
    # This method can be passed attribute names and an optional time argument.
    # If attribute names are passed, they are updated along with updated_at/on attributes.
    # If no time argument is passed, the current time is used as default.
    #
    # === Examples
    #
    #   # Touch all records
    #   Person.all.touch_all
    #   # => "UPDATE \"people\" SET \"updated_at\" = '2018-01-04 22:55:23.132670'"
    #
    #   # Touch multiple records with a custom attribute
    #   Person.all.touch_all(:created_at)
    #   # => "UPDATE \"people\" SET \"updated_at\" = '2018-01-04 22:55:23.132670', \"created_at\" = '2018-01-04 22:55:23.132670'"
    #
    #   # Touch multiple records with a specified time
    #   Person.all.touch_all(time: Time.new(2020, 5, 16, 0, 0, 0))
    #   # => "UPDATE \"people\" SET \"updated_at\" = '2020-05-16 00:00:00'"
    #
    #   # Touch records with scope
    #   Person.where(name: 'David').touch_all
    #   # => "UPDATE \"people\" SET \"updated_at\" = '2018-01-04 22:55:23.132670' WHERE \"people\".\"name\" = 'David'"
    def touch_all(*names, time: nil)
      attributes = Array(names) + klass.timestamp_attributes_for_update_in_model
      time ||= klass.current_time_from_proper_timezone
      updates = {}
      attributes.each { |column| updates[column] = time }

      if klass.locking_enabled?
        quoted_locking_column = connection.quote_column_name(klass.locking_column)
        updates = sanitize_sql_for_assignment(updates) + ", #{quoted_locking_column} = COALESCE(#{quoted_locking_column}, 0) + 1"
      end

      update_all(updates)
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
    def destroy_all
      records.each(&:destroy).tap { reset }
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
    #   Post.distinct.delete_all
    #   # => ActiveRecord::ActiveRecordError: delete_all doesn't support distinct
    def delete_all
      invalid_methods = INVALID_METHODS_FOR_DELETE_ALL.select do |method|
        value = get_value(method)
        SINGLE_VALUE_METHODS.include?(method) ? value : value.any?
      end
      if invalid_methods.any?
        raise ActiveRecordError.new("delete_all doesn't support #{invalid_methods.join(', ')}")
      end

      if eager_loading?
        relation = apply_join_dependency
        return relation.delete_all
      end

      stmt = Arel::DeleteManager.new
      stmt.from(table)

      if has_join_values? || has_limit_or_offset?
        @klass.connection.join_to_delete(stmt, arel, arel_attribute(primary_key))
      else
        stmt.wheres = arel.constraints
      end

      affected = @klass.connection.delete(stmt, "#{@klass} Destroy")

      reset
      affected
    end

    # Causes the records to be loaded from the database if they have not
    # been loaded already. You can use this if for some reason you need
    # to explicitly load some records before actually using them. The
    # return value is the relation itself, not the records.
    #
    #   Post.where(published: true).load # => #<ActiveRecord::Relation>
    def load(&block)
      exec_queries(&block) unless loaded?

      self
    end

    # Forces reloading of relation.
    def reload
      reset
      load
    end

    def reset
      @delegate_to_klass = false
      @to_sql = @arel = @loaded = @should_eager_load = nil
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
                      apply_join_dependency { |rel, _| relation = rel }
                    end

                    conn = klass.connection
                    conn.unprepared_statement {
                      conn.to_sql(relation.arel)
                    }
                  end
    end

    # Returns a hash of where conditions.
    #
    #   User.where(name: 'Oscar').where_values_hash
    #   # => {name: "Oscar"}
    def where_values_hash(relation_table_name = klass.table_name)
      where_clause.to_h(relation_table_name)
    end

    def scope_for_create(attributes = nil)
      scope = where_values_hash.merge!(create_with_value.stringify_keys)
      scope.merge!(attributes) if attributes
      scope
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
      q.pp(records)
    end

    # Returns true if relation is blank.
    def blank?
      records.blank?
    end

    def values
      @values.dup
    end

    def inspect
      subject = loaded? ? records : self
      entries = subject.take([limit_value, 11].compact.min).map!(&:inspect)

      entries[10] = "..." if entries.size == 11

      "#<#{self.class.name} [#{entries.join(', ')}]>"
    end

    def empty_scope? # :nodoc:
      @values == klass.unscoped.values
    end

    def has_limit_or_offset? # :nodoc:
      limit_value || offset_value
    end

    def alias_tracker(joins = [], aliases = nil) # :nodoc:
      joins += [aliases] if aliases
      ActiveRecord::Associations::AliasTracker.create(connection, table.name, joins)
    end

    def preload_associations(records) # :nodoc:
      preload = preload_values
      preload += includes_values unless eager_loading?
      preloader = nil
      preload.each do |associations|
        preloader ||= build_preloader
        preloader.preload records, associations
      end
    end

    protected

      def load_records(records)
        @records = records.freeze
        @loaded = true
      end

    private

      def has_join_values?
        joins_values.any? || left_outer_joins_values.any?
      end

      def exec_queries(&block)
        skip_query_cache_if_necessary do
          @records =
            if eager_loading?
              apply_join_dependency do |relation, join_dependency|
                if ActiveRecord::NullRelation === relation
                  []
                else
                  rows = connection.select_all(relation.arel, "SQL")
                  join_dependency.instantiate(rows, &block)
                end.freeze
              end
            else
              klass.find_by_sql(arel, &block).freeze
            end

          preload_associations(@records) unless skip_preloading_value

          @records.each(&:readonly!) if readonly_value

          @loaded = true
          @records
        end
      end

      def skip_query_cache_if_necessary
        if skip_query_cache_value
          uncached do
            yield
          end
        else
          yield
        end
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
