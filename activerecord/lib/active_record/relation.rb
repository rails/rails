# frozen_string_literal: true

module ActiveRecord
  # = Active Record \Relation
  class Relation
    MULTI_VALUE_METHODS  = [:includes, :eager_load, :preload, :select, :group,
                            :order, :joins, :left_outer_joins, :references,
                            :extending, :unscope, :optimizer_hints, :annotate]

    SINGLE_VALUE_METHODS = [:limit, :offset, :lock, :readonly, :reordering, :strict_loading,
                            :reverse_order, :distinct, :create_with, :skip_query_cache]

    CLAUSE_METHODS = [:where, :having, :from]
    INVALID_METHODS_FOR_DELETE_ALL = [:distinct]

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
      @loaded = false
      @predicate_builder = predicate_builder
      @delegate_to_klass = false
      @future_result = nil
      @records = nil
    end

    def initialize_copy(other)
      @values = @values.dup
      reset
    end

    def bind_attribute(name, value) # :nodoc:
      if reflection = klass._reflect_on_association(name)
        name = reflection.foreign_key
        value = value.read_attribute(reflection.klass.primary_key) unless value.nil?
      end

      attr = table[name]
      bind = predicate_builder.build_bind_attribute(attr.name, value)
      yield attr, bind
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
      if attributes.is_a?(Array)
        attributes.collect { |attr| new(attr, &block) }
      else
        block = current_scope_restoring_block(&block)
        scoping { _new(attributes, &block) }
      end
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
        block = current_scope_restoring_block(&block)
        scoping { _create(attributes, &block) }
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
        block = current_scope_restoring_block(&block)
        scoping { _create!(attributes, &block) }
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
    #   # particular last name.
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

    # Attempts to create a record with the given attributes in a table that has a unique database constraint
    # on one or several of its columns. If a row already exists with one or several of these
    # unique constraints, the exception such an insertion would normally raise is caught,
    # and the existing record with those attributes is found using #find_by!.
    #
    # This is similar to #find_or_create_by, but avoids the problem of stale reads between the SELECT
    # and the INSERT, as that method needs to first query the table, then attempt to insert a row
    # if none is found.
    #
    # There are several drawbacks to #create_or_find_by, though:
    #
    # * The underlying table must have the relevant columns defined with unique database constraints.
    # * A unique constraint violation may be triggered by only one, or at least less than all,
    #   of the given attributes. This means that the subsequent #find_by! may fail to find a
    #   matching record, which will then raise an <tt>ActiveRecord::RecordNotFound</tt> exception,
    #   rather than a record with the given attributes.
    # * While we avoid the race condition between SELECT -> INSERT from #find_or_create_by,
    #   we actually have another race condition between INSERT -> SELECT, which can be triggered
    #   if a DELETE between those two statements is run by another client. But for most applications,
    #   that's a significantly less likely condition to hit.
    # * It relies on exception handling to handle control flow, which may be marginally slower.
    # * The primary key may auto-increment on each create, even if it fails. This can accelerate
    #   the problem of running out of integers, if the underlying table is still stuck on a primary
    #   key of type int (note: All Rails apps since 5.1+ have defaulted to bigint, which is not liable
    #   to this problem).
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
    # {Active Record Query Interface guide}[https://guides.rubyonrails.org/active_record_querying.html#running-explain].
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
      if loaded?
        records.length
      else
        count(:all)
      end
    end

    # Returns true if there are no records.
    def empty?
      if loaded?
        records.empty?
      else
        !exists?
      end
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
      return records.one? if loaded?
      limited_count == 1
    end

    # Returns true if there is more than one record.
    def many?
      return super if block_given?
      return records.many? if loaded?
      limited_count > 1
    end

    # Returns a stable cache key that can be used to identify this query.
    # The cache key is built with a fingerprint of the SQL query.
    #
    #    Product.where("name like ?", "%Cosmic Encounter%").cache_key
    #    # => "products/query-1850ab3d302391b85b8693e941286659"
    #
    # If ActiveRecord::Base.collection_cache_versioning is turned off, as it was
    # in Rails 6.0 and earlier, the cache key will also include a version.
    #
    #    ActiveRecord::Base.collection_cache_versioning = false
    #    Product.where("name like ?", "%Cosmic Encounter%").cache_key
    #    # => "products/query-1850ab3d302391b85b8693e941286659-1-20150714212553907087000"
    #
    # You can also pass a custom timestamp column to fetch the timestamp of the
    # last updated record.
    #
    #   Product.where("name like ?", "%Game%").cache_key(:last_reviewed_at)
    def cache_key(timestamp_column = "updated_at")
      @cache_keys ||= {}
      @cache_keys[timestamp_column] ||= klass.collection_cache_key(self, timestamp_column)
    end

    def compute_cache_key(timestamp_column = :updated_at) # :nodoc:
      query_signature = ActiveSupport::Digest.hexdigest(to_sql)
      key = "#{klass.model_name.cache_key}/query-#{query_signature}"

      if collection_cache_versioning
        key
      else
        "#{key}-#{compute_cache_version(timestamp_column)}"
      end
    end
    private :compute_cache_key

    # Returns a cache version that can be used together with the cache key to form
    # a recyclable caching scheme. The cache version is built with the number of records
    # matching the query, and the timestamp of the last updated record. When a new record
    # comes to match the query, or any of the existing records is updated or deleted,
    # the cache version changes.
    #
    # If the collection is loaded, the method will iterate through the records
    # to generate the timestamp, otherwise it will trigger one SQL query like:
    #
    #    SELECT COUNT(*), MAX("products"."updated_at") FROM "products" WHERE (name like '%Cosmic Encounter%')
    def cache_version(timestamp_column = :updated_at)
      if collection_cache_versioning
        @cache_versions ||= {}
        @cache_versions[timestamp_column] ||= compute_cache_version(timestamp_column)
      end
    end

    def compute_cache_version(timestamp_column) # :nodoc:
      timestamp_column = timestamp_column.to_s

      if loaded?
        size = records.size
        if size > 0
          timestamp = records.map { |record| record.read_attribute(timestamp_column) }.max
        end
      else
        collection = eager_loading? ? apply_join_dependency : self

        column = connection.visitor.compile(table[timestamp_column])
        select_values = "COUNT(*) AS #{connection.quote_column_name("size")}, MAX(%s) AS timestamp"

        if collection.has_limit_or_offset?
          query = collection.select("#{column} AS collection_cache_key_timestamp")
          query._select!(table[Arel.star]) if distinct_value && collection.select_values.empty?
          subquery_alias = "subquery_for_cache_key"
          subquery_column = "#{subquery_alias}.collection_cache_key_timestamp"
          arel = query.build_subquery(subquery_alias, select_values % subquery_column)
        else
          query = collection.unscope(:order)
          query.select_values = [select_values % column]
          arel = query.arel
        end

        size, timestamp = connection.select_rows(arel, nil).first

        if size
          column_type = klass.type_for_attribute(timestamp_column)
          timestamp = column_type.deserialize(timestamp)
        else
          size = 0
        end
      end

      if timestamp
        "#{size}-#{timestamp.utc.to_formatted_s(cache_timestamp_format)}"
      else
        "#{size}"
      end
    end
    private :compute_cache_version

    # Returns a cache key along with the version.
    def cache_key_with_version
      if version = cache_version
        "#{cache_key}-#{version}"
      else
        cache_key
      end
    end

    # Scope all queries to the current scope.
    #
    #   Comment.where(post_id: 1).scoping do
    #     Comment.first
    #   end
    #   # => SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = 1 ORDER BY "comments"."id" ASC LIMIT 1
    #
    # If <tt>all_queries: true</tt> is passed, scoping will apply to all queries
    # for the relation including +update+ and +delete+ on instances.
    # Once +all_queries+ is set to true it cannot be set to false in a
    # nested block.
    #
    # Please check unscoped if you want to remove all previous scopes (including
    # the default_scope) during the execution of a block.
    def scoping(all_queries: nil, &block)
      registry = klass.scope_registry
      if global_scope?(registry) && all_queries == false
        raise ArgumentError, "Scoping is set to apply to all queries and cannot be unset in a nested block."
      elsif already_in_scope?(registry)
        yield
      else
        _scoping(self, registry, all_queries, &block)
      end
    end

    def _exec_scope(*args, &block) # :nodoc:
      @delegate_to_klass = true
      registry = klass.scope_registry
      _scoping(nil, registry) { instance_exec(*args, &block) || self }
    ensure
      @delegate_to_klass = false
    end

    # Updates all records in the current relation with details given. This method constructs a single SQL UPDATE
    # statement and sends it straight to the database. It does not instantiate the involved models and it does not
    # trigger Active Record callbacks or validations. However, values passed to #update_all will still go through
    # Active Record's normal type casting and serialization. Returns the number of rows affected.
    #
    # Note: As Active Record callbacks are not triggered, this method will not automatically update +updated_at+/+updated_on+ columns.
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

      if updates.is_a?(Hash)
        if klass.locking_enabled? &&
            !updates.key?(klass.locking_column) &&
            !updates.key?(klass.locking_column.to_sym)
          attr = table[klass.locking_column]
          updates[attr.name] = _increment_attribute(attr)
        end
        values = _substitute_values(updates)
      else
        values = Arel.sql(klass.sanitize_sql_for_assignment(updates, table.name))
      end

      arel = eager_loading? ? apply_join_dependency.arel : build_arel
      arel.source.left = table

      group_values_arel_columns = arel_columns(group_values.uniq)
      having_clause_ast = having_clause.ast unless having_clause.empty?
      stmt = arel.compile_update(values, table[primary_key], having_clause_ast, group_values_arel_columns)
      klass.connection.update(stmt, "#{klass} Update All").tap { reset }
    end

    def update(id = :all, attributes) # :nodoc:
      if id == :all
        each { |record| record.update(attributes) }
      else
        klass.update(id, attributes)
      end
    end

    def update!(id = :all, attributes) # :nodoc:
      if id == :all
        each { |record| record.update!(attributes) }
      else
        klass.update!(id, attributes)
      end
    end

    # Updates the counters of the records in the current relation.
    #
    # ==== Parameters
    #
    # * +counter+ - A Hash containing the names of the fields to update as keys and the amount to update as values.
    # * <tt>:touch</tt> option - Touch the timestamp columns when updating.
    # * If attributes names are passed, they are updated along with update_at/on attributes.
    #
    # ==== Examples
    #
    #   # For Posts by a given author increment the comment_count by 1.
    #   Post.where(author_id: author.id).update_counters(comment_count: 1)
    def update_counters(counters)
      touch = counters.delete(:touch)

      updates = {}
      counters.each do |counter_name, value|
        attr = table[counter_name]
        updates[attr.name] = _increment_attribute(attr, value)
      end

      if touch
        names = touch if touch != true
        names = Array.wrap(names)
        options = names.extract_options!
        touch_updates = klass.touch_attributes_with_time(*names, **options)
        updates.merge!(touch_updates) unless touch_updates.empty?
      end

      update_all updates
    end

    # Touches all records in the current relation, setting the +updated_at+/+updated_on+ attributes to the current time or the time specified.
    # It does not instantiate the involved models, and it does not trigger Active Record callbacks or validations.
    # This method can be passed attribute names and an optional time argument.
    # If attribute names are passed, they are updated along with +updated_at+/+updated_on+ attributes.
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
      update_all klass.touch_attributes_with_time(*names, time: time)
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
        value = @values[method]
        method == :distinct ? value : value&.any?
      end
      if invalid_methods.any?
        raise ActiveRecordError.new("delete_all doesn't support #{invalid_methods.join(', ')}")
      end

      arel = eager_loading? ? apply_join_dependency.arel : build_arel
      arel.source.left = table

      group_values_arel_columns = arel_columns(group_values.uniq)
      having_clause_ast = having_clause.ast unless having_clause.empty?
      stmt = arel.compile_delete(table[primary_key], having_clause_ast, group_values_arel_columns)

      klass.connection.delete(stmt, "#{klass} Delete All").tap { reset }
    end

    # Finds and destroys all records matching the specified conditions.
    # This is short-hand for <tt>relation.where(condition).destroy_all</tt>.
    # Returns the collection of objects that were destroyed.
    #
    # If no record is found, returns empty array.
    #
    #   Person.destroy_by(id: 13)
    #   Person.destroy_by(name: 'Spartacus', rating: 4)
    #   Person.destroy_by("published_at < ?", 2.weeks.ago)
    def destroy_by(*args)
      where(*args).destroy_all
    end

    # Finds and deletes all records matching the specified conditions.
    # This is short-hand for <tt>relation.where(condition).delete_all</tt>.
    # Returns the number of rows affected.
    #
    # If no record is found, returns <tt>0</tt> as zero rows were affected.
    #
    #   Person.delete_by(id: 13)
    #   Person.delete_by(name: 'Spartacus', rating: 4)
    #   Person.delete_by("published_at < ?", 2.weeks.ago)
    def delete_by(*args)
      where(*args).delete_all
    end

    # Schedule the query to be performed from a background thread pool.
    #
    #   Post.where(published: true).load_async # => #<ActiveRecord::Relation>
    def load_async
      return load if !connection.async_enabled?

      unless loaded?
        result = exec_main_query(async: connection.current_transaction.closed?)

        if result.is_a?(Array)
          @records = result
        else
          @future_result = result
        end
        @loaded = true
      end

      self
    end

    # Returns <tt>true</tt> if the relation was scheduled on the background
    # thread pool.
    def scheduled?
      !!@future_result
    end

    # Causes the records to be loaded from the database if they have not
    # been loaded already. You can use this if for some reason you need
    # to explicitly load some records before actually using them. The
    # return value is the relation itself, not the records.
    #
    #   Post.where(published: true).load # => #<ActiveRecord::Relation>
    def load(&block)
      if !loaded? || scheduled?
        @records = exec_queries(&block)
        @loaded = true
      end

      self
    end

    # Forces reloading of relation.
    def reload
      reset
      load
    end

    def reset
      @future_result&.cancel
      @future_result = nil
      @delegate_to_klass = false
      @to_sql = @arel = @loaded = @should_eager_load = nil
      @offsets = @take = nil
      @cache_keys = nil
      @records = nil
      self
    end

    # Returns sql statement for the relation.
    #
    #   User.where(name: 'Oscar').to_sql
    #   # => SELECT "users".* FROM "users"  WHERE "users"."name" = 'Oscar'
    def to_sql
      @to_sql ||= if eager_loading?
        apply_join_dependency do |relation, join_dependency|
          relation = join_dependency.apply_column_aliases(relation)
          relation.to_sql
        end
      else
        conn = klass.connection
        conn.unprepared_statement { conn.to_sql(arel) }
      end
    end

    # Returns a hash of where conditions.
    #
    #   User.where(name: 'Oscar').where_values_hash
    #   # => {name: "Oscar"}
    def where_values_hash(relation_table_name = klass.table_name)
      where_clause.to_h(relation_table_name)
    end

    def scope_for_create
      hash = where_clause.to_h(klass.table_name, equality_only: true)
      create_with_value.each { |k, v| hash[k.to_s] = v } unless create_with_value.empty?
      hash
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

    def values_for_queries # :nodoc:
      @values.except(:extending, :skip_query_cache, :strict_loading)
    end

    def inspect
      subject = loaded? ? records : annotate("loading for inspect")
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
      ActiveRecord::Associations::AliasTracker.create(connection, table.name, joins, aliases)
    end

    class StrictLoadingScope # :nodoc:
      def self.empty_scope?
        true
      end

      def self.strict_loading_value
        true
      end
    end

    def preload_associations(records) # :nodoc:
      preload = preload_values
      preload += includes_values unless eager_loading?
      scope = strict_loading_value ? StrictLoadingScope : nil
      preload.each do |associations|
        ActiveRecord::Associations::Preloader.new(records: records, associations: associations, scope: scope).call
      end
    end

    protected
      def load_records(records)
        @records = records.freeze
        @loaded = true
      end

      def null_relation? # :nodoc:
        is_a?(NullRelation)
      end

    private
      def already_in_scope?(registry)
        @delegate_to_klass && registry.current_scope(klass, true)
      end

      def global_scope?(registry)
        registry.global_current_scope(klass, true)
      end

      def current_scope_restoring_block(&block)
        current_scope = klass.current_scope(true)
        -> record do
          klass.current_scope = current_scope
          yield record if block_given?
        end
      end

      def _new(attributes, &block)
        klass.new(attributes, &block)
      end

      def _create(attributes, &block)
        klass.create(attributes, &block)
      end

      def _create!(attributes, &block)
        klass.create!(attributes, &block)
      end

      def _scoping(scope, registry, all_queries = false)
        previous = registry.current_scope(klass, true)
        registry.set_current_scope(klass, scope)

        if all_queries
          previous_global = registry.global_current_scope(klass, true)
          registry.set_global_current_scope(klass, scope)
        end
        yield
      ensure
        registry.set_current_scope(klass, previous)
        if all_queries
          registry.set_global_current_scope(klass, previous_global)
        end
      end

      def _substitute_values(values)
        values.map do |name, value|
          attr = table[name]
          unless Arel.arel_node?(value)
            type = klass.type_for_attribute(attr.name)
            value = predicate_builder.build_bind_attribute(attr.name, type.cast(value))
          end
          [attr, value]
        end
      end

      def _increment_attribute(attribute, value = 1)
        bind = predicate_builder.build_bind_attribute(attribute.name, value.abs)
        expr = table.coalesce(Arel::Nodes::UnqualifiedColumn.new(attribute), 0)
        expr = value < 0 ? expr - bind : expr + bind
        expr.expr
      end

      def exec_queries(&block)
        skip_query_cache_if_necessary do
          rows = if scheduled?
            future = @future_result
            @future_result = nil
            future.result
          else
            exec_main_query
          end

          records = instantiate_records(rows, &block)
          preload_associations(records) unless skip_preloading_value

          records.each(&:readonly!) if readonly_value
          records.each(&:strict_loading!) if strict_loading_value

          records
        end
      end

      def exec_main_query(async: false)
        skip_query_cache_if_necessary do
          if where_clause.contradiction?
            [].freeze
          elsif eager_loading?
            apply_join_dependency do |relation, join_dependency|
              if relation.null_relation?
                [].freeze
              else
                relation = join_dependency.apply_column_aliases(relation)
                @_join_dependency = join_dependency
                connection.select_all(relation.arel, "SQL", async: async)
              end
            end
          else
            klass._query_by_sql(arel, async: async)
          end
        end
      end

      def instantiate_records(rows, &block)
        return [].freeze if rows.empty?
        if eager_loading?
          records = @_join_dependency.instantiate(rows, strict_loading_value, &block).freeze
          @_join_dependency = nil
          records
        else
          klass._load_from_sql(rows, &block).freeze
        end
      end

      def skip_query_cache_if_necessary(&block)
        if skip_query_cache_value
          uncached(&block)
        else
          yield
        end
      end

      def references_eager_loaded_tables?
        joined_tables = build_joins([]).flat_map do |join|
          if join.is_a?(Arel::Nodes::StringJoin)
            tables_in_string(join.left)
          else
            join.left.name
          end
        end

        joined_tables << table.name

        # always convert table names to downcase as in Oracle quoted table names are in uppercase
        joined_tables.map!(&:downcase)

        !(references_values.map(&:to_s) - joined_tables).empty?
      end

      def tables_in_string(string)
        return [] if string.blank?
        # always convert table names to downcase as in Oracle quoted table names are in uppercase
        # ignore raw_sql_ that is used by Oracle adapter as alias for limit/offset subqueries
        string.scan(/[a-zA-Z_][.\w]+(?=.?\.)/).map!(&:downcase) - ["raw_sql_"]
      end

      def limited_count
        limit_value ? count : limit(2).count
      end
  end
end
