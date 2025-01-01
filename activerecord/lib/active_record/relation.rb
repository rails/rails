# frozen_string_literal: true

module ActiveRecord
  # = Active Record \Relation
  class Relation
    class ExplainProxy  # :nodoc:
      def initialize(relation, options)
        @relation = relation
        @options  = options
      end

      def inspect
        exec_explain { @relation.send(:exec_queries) }
      end

      def average(column_name)
        exec_explain { @relation.average(column_name) }
      end

      def count(column_name = nil)
        exec_explain { @relation.count(column_name) }
      end

      def first(limit = nil)
        exec_explain { @relation.first(limit) }
      end

      def last(limit = nil)
        exec_explain { @relation.last(limit) }
      end

      def maximum(column_name)
        exec_explain { @relation.maximum(column_name) }
      end

      def minimum(column_name)
        exec_explain { @relation.minimum(column_name) }
      end

      def pluck(*column_names)
        exec_explain { @relation.pluck(*column_names) }
      end

      def sum(identity_or_column = nil)
        exec_explain { @relation.sum(identity_or_column) }
      end

      private
        def exec_explain(&block)
          @relation.exec_explain(@relation.collecting_queries_for_explain { block.call }, @options)
        end
    end

    MULTI_VALUE_METHODS  = [:includes, :eager_load, :preload, :select, :group,
                            :order, :joins, :left_outer_joins, :references,
                            :extending, :unscope, :optimizer_hints, :annotate,
                            :with]

    SINGLE_VALUE_METHODS = [:limit, :offset, :lock, :readonly, :reordering, :strict_loading,
                            :reverse_order, :distinct, :create_with, :skip_query_cache]

    CLAUSE_METHODS = [:where, :having, :from]
    INVALID_METHODS_FOR_DELETE_ALL = [:distinct, :with, :with_recursive]

    VALUE_METHODS = MULTI_VALUE_METHODS + SINGLE_VALUE_METHODS + CLAUSE_METHODS

    include Enumerable
    include FinderMethods, Calculations, SpawnMethods, QueryMethods, Batches, Explain, Delegation
    include SignedId::RelationMethods, TokenFor::RelationMethods

    attr_reader :table, :model, :loaded, :predicate_builder
    attr_accessor :skip_preloading_value
    alias :klass :model
    alias :loaded? :loaded
    alias :locked? :lock_value

    def initialize(model, table: nil, predicate_builder: nil, values: {})
      if table
        predicate_builder ||= model.predicate_builder.with(TableMetadata.new(model, table))
      else
        table = model.arel_table
        predicate_builder ||= model.predicate_builder
      end

      @model  = model
      @table  = table
      @values = values
      @loaded = false
      @predicate_builder = predicate_builder
      @delegate_to_model = false
      @future_result = nil
      @records = nil
      @async = false
      @none = false
    end

    def initialize_copy(other)
      @values = @values.dup
      reset
    end

    def bind_attribute(name, value) # :nodoc:
      if reflection = model._reflect_on_association(name)
        name = reflection.foreign_key
        value = value.read_attribute(reflection.association_primary_key) unless value.nil?
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
    # If creation failed because of a unique constraint, this method will
    # assume it encountered a race condition and will try finding the record
    # once more. If somehow the second find still does not find a record
    # because a concurrent DELETE happened, it will then raise an
    # ActiveRecord::RecordNotFound exception.
    #
    # Please note <b>this method is not atomic</b>, it runs first a SELECT,
    # and if there are no results an INSERT is attempted. So if the table
    # doesn't have a relevant unique constraint it could be the case that
    # you end up with two or more similar records.
    def find_or_create_by(attributes, &block)
      find_by(attributes) || create_or_find_by(attributes, &block)
    end

    # Like #find_or_create_by, but calls
    # {create!}[rdoc-ref:Persistence::ClassMethods#create!] so an exception
    # is raised if the created record is invalid.
    def find_or_create_by!(attributes, &block)
      find_by(attributes) || create_or_find_by!(attributes, &block)
    end

    # Attempts to create a record with the given attributes in a table that has a unique database constraint
    # on one or several of its columns. If a row already exists with one or several of these
    # unique constraints, the exception such an insertion would normally raise is caught,
    # and the existing record with those attributes is found using #find_by!.
    #
    # This is similar to #find_or_create_by, but tries to create the record first. As such it is
    # better suited for cases where the record is most likely not to exist yet.
    #
    # There are several drawbacks to #create_or_find_by, though:
    #
    # * The underlying table must have the relevant columns defined with unique database constraints.
    # * A unique constraint violation may be triggered by only one, or at least less than all,
    #   of the given attributes. This means that the subsequent #find_by! may fail to find a
    #   matching record, which will then raise an ActiveRecord::RecordNotFound exception,
    #   rather than a record with the given attributes.
    # * While we avoid the race condition between SELECT -> INSERT from #find_or_create_by,
    #   we actually have another race condition between INSERT -> SELECT, which can be triggered
    #   if a DELETE between those two statements is run by another client. But for most applications,
    #   that's a significantly less likely condition to hit.
    # * It relies on exception handling to handle control flow, which may be marginally slower.
    # * The primary key may auto-increment on each create, even if it fails. This can accelerate
    #   the problem of running out of integers, if the underlying table is still stuck on a primary
    #   key of type int (note: All \Rails apps since 5.1+ have defaulted to bigint, which is not liable
    #   to this problem).
    # * Columns with unique database constraints should not have uniqueness validations defined,
    #   otherwise #create will fail due to validation errors and #find_by will never be called.
    #
    # This method will return a record if all given attributes are covered by unique constraints
    # (unless the INSERT -> DELETE -> SELECT race condition is triggered), but if creation was attempted
    # and failed due to validation errors it won't be persisted, you get what #create returns in
    # such situation.
    def create_or_find_by(attributes, &block)
      with_connection do |connection|
        transaction(requires_new: true) { create(attributes, &block) }
      rescue ActiveRecord::RecordNotUnique
        if connection.transaction_open?
          where(attributes).lock.find_by!(attributes)
        else
          find_by!(attributes)
        end
      end
    end

    # Like #create_or_find_by, but calls
    # {create!}[rdoc-ref:Persistence::ClassMethods#create!] so an exception
    # is raised if the created record is invalid.
    def create_or_find_by!(attributes, &block)
      with_connection do |connection|
        transaction(requires_new: true) { create!(attributes, &block) }
      rescue ActiveRecord::RecordNotUnique
        if connection.transaction_open?
          where(attributes).lock.find_by!(attributes)
        else
          find_by!(attributes)
        end
      end
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
    #   User.all.explain
    #   # EXPLAIN SELECT `users`.* FROM `users`
    #   # ...
    #
    # Note that this method actually runs the queries, since the results of some
    # are needed by the next ones when eager loading is going on.
    #
    # To run EXPLAIN on queries created by +first+, +pluck+ and +count+, call
    # these methods on +explain+:
    #
    #   User.all.explain.count
    #   # EXPLAIN SELECT COUNT(*) FROM `users`
    #   # ...
    #
    # The column name can be passed if required:
    #
    #   User.all.explain.maximum(:id)
    #   # EXPLAIN SELECT MAX(`users`.`id`) FROM `users`
    #   # ...
    #
    # Please see further details in the
    # {Active Record Query Interface guide}[https://guides.rubyonrails.org/active_record_querying.html#running-explain].
    def explain(*options)
      ExplainProxy.new(self, options)
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
      return true if @none

      if loaded?
        records.empty?
      else
        !exists?
      end
    end

    # Returns true if there are no records.
    #
    # When a pattern argument is given, this method checks whether elements in
    # the Enumerable match the pattern via the case-equality operator (<tt>===</tt>).
    #
    #   posts.none?(Comment) # => true or false
    def none?(*args)
      return true if @none

      return super if args.present? || block_given?
      empty?
    end

    # Returns true if there are any records.
    #
    # When a pattern argument is given, this method checks whether elements in
    # the Enumerable match the pattern via the case-equality operator (<tt>===</tt>).
    #
    #    posts.any?(Post) # => true or false
    def any?(*args)
      return false if @none

      return super if args.present? || block_given?
      !empty?
    end

    # Returns true if there is exactly one record.
    #
    # When a pattern argument is given, this method checks whether elements in
    # the Enumerable match the pattern via the case-equality operator (<tt>===</tt>).
    #
    #    posts.one?(Post) # => true or false
    def one?(*args)
      return false if @none

      return super if args.present? || block_given?
      return records.one? if loaded?
      limited_count == 1
    end

    # Returns true if there is more than one record.
    def many?
      return false if @none

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
    # in \Rails 6.0 and earlier, the cache key will also include a version.
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
      @cache_keys[timestamp_column] ||= model.collection_cache_key(self, timestamp_column)
    end

    def compute_cache_key(timestamp_column = :updated_at) # :nodoc:
      query_signature = ActiveSupport::Digest.hexdigest(to_sql)
      key = "#{model.model_name.cache_key}/query-#{query_signature}"

      if model.collection_cache_versioning
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
      if model.collection_cache_versioning
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

        with_connection do |c|
          column = c.visitor.compile(table[timestamp_column])
          select_values = "COUNT(*) AS #{model.adapter_class.quote_column_name("size")}, MAX(%s) AS timestamp"

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

          size, timestamp = c.select_rows(arel, nil).first

          if size
            column_type = model.type_for_attribute(timestamp_column)
            timestamp = column_type.deserialize(timestamp)
          else
            size = 0
          end
        end
      end

      if timestamp
        "#{size}-#{timestamp.utc.to_fs(model.cache_timestamp_format)}"
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
    #   # SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = 1 ORDER BY "comments"."id" ASC LIMIT 1
    #
    # If <tt>all_queries: true</tt> is passed, scoping will apply to all queries
    # for the relation including +update+ and +delete+ on instances.
    # Once +all_queries+ is set to true it cannot be set to false in a
    # nested block.
    #
    # Please check unscoped if you want to remove all previous scopes (including
    # the default_scope) during the execution of a block.
    def scoping(all_queries: nil, &block)
      registry = model.scope_registry
      if global_scope?(registry) && all_queries == false
        raise ArgumentError, "Scoping is set to apply to all queries and cannot be unset in a nested block."
      elsif already_in_scope?(registry)
        yield
      else
        _scoping(self, registry, all_queries, &block)
      end
    end

    def _exec_scope(...) # :nodoc:
      @delegate_to_model = true
      registry = model.scope_registry
      _scoping(nil, registry) { instance_exec(...) || self }
    ensure
      @delegate_to_model = false
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
    # * +updates+ - A string, array, or hash representing the SET part of an SQL statement. Any strings provided will
    #   be type cast, unless you use +Arel.sql+. (Don't pass user-provided values to +Arel.sql+.)
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
    #
    #   # Update all books with 'Rails' in their title
    #   Book.where('title LIKE ?', '%Rails%').update_all(title: Arel.sql("title + ' - volume 1'"))
    def update_all(updates)
      raise ArgumentError, "Empty list of attributes to change" if updates.blank?

      return 0 if @none

      if updates.is_a?(Hash)
        if model.locking_enabled? &&
            !updates.key?(model.locking_column) &&
            !updates.key?(model.locking_column.to_sym)
          attr = table[model.locking_column]
          updates[attr.name] = _increment_attribute(attr)
        end
        values = _substitute_values(updates)
      else
        values = Arel.sql(model.sanitize_sql_for_assignment(updates, table.name))
      end

      model.with_connection do |c|
        arel = eager_loading? ? apply_join_dependency.arel : build_arel(c)
        arel.source.left = table

        group_values_arel_columns = arel_columns(group_values.uniq)
        having_clause_ast = having_clause.ast unless having_clause.empty?
        key = if model.composite_primary_key?
          primary_key.map { |pk| table[pk] }
        else
          table[primary_key]
        end
        stmt = arel.compile_update(values, key, having_clause_ast, group_values_arel_columns)
        c.update(stmt, "#{model} Update All").tap { reset }
      end
    end

    def update(id = :all, attributes) # :nodoc:
      if id == :all
        each { |record| record.update(attributes) }
      else
        model.update(id, attributes)
      end
    end

    def update!(id = :all, attributes) # :nodoc:
      if id == :all
        each { |record| record.update!(attributes) }
      else
        model.update!(id, attributes)
      end
    end


    # Inserts a single record into the database in a single SQL INSERT
    # statement. It does not instantiate any models nor does it trigger
    # Active Record callbacks or validations. Though passed values
    # go through Active Record's type casting and serialization.
    #
    # See #insert_all for documentation.
    def insert(attributes, returning: nil, unique_by: nil, record_timestamps: nil)
      insert_all([ attributes ], returning: returning, unique_by: unique_by, record_timestamps: record_timestamps)
    end

    # Inserts multiple records into the database in a single SQL INSERT
    # statement. It does not instantiate any models nor does it trigger
    # Active Record callbacks or validations. Though passed values
    # go through Active Record's type casting and serialization.
    #
    # The +attributes+ parameter is an Array of Hashes. Every Hash determines
    # the attributes for a single row and must have the same keys.
    #
    # Rows are considered to be unique by every unique index on the table. Any
    # duplicate rows are skipped.
    # Override with <tt>:unique_by</tt> (see below).
    #
    # Returns an ActiveRecord::Result with its contents based on
    # <tt>:returning</tt> (see below).
    #
    # ==== Options
    #
    # [:returning]
    #   (PostgreSQL, SQLite3, and MariaDB only) An array of attributes to return for all successfully
    #   inserted records, which by default is the primary key.
    #   Pass <tt>returning: %w[ id name ]</tt> for both id and name
    #   or <tt>returning: false</tt> to omit the underlying <tt>RETURNING</tt> SQL
    #   clause entirely.
    #
    #   You can also pass an SQL string if you need more control on the return values
    #   (for example, <tt>returning: Arel.sql("id, name as new_name")</tt>).
    #
    # [:unique_by]
    #   (PostgreSQL and SQLite only) By default rows are considered to be unique
    #   by every unique index on the table. Any duplicate rows are skipped.
    #
    #   To skip rows according to just one unique index pass <tt>:unique_by</tt>.
    #
    #   Consider a Book model where no duplicate ISBNs make sense, but if any
    #   row has an existing id, or is not unique by another unique index,
    #   ActiveRecord::RecordNotUnique is raised.
    #
    #   Unique indexes can be identified by columns or name:
    #
    #     unique_by: :isbn
    #     unique_by: %i[ author_id name ]
    #     unique_by: :index_books_on_isbn
    #
    # [:record_timestamps]
    #   By default, automatic setting of timestamp columns is controlled by
    #   the model's <tt>record_timestamps</tt> config, matching typical
    #   behavior.
    #
    #   To override this and force automatic setting of timestamp columns one
    #   way or the other, pass <tt>:record_timestamps</tt>:
    #
    #     record_timestamps: true  # Always set timestamps automatically
    #     record_timestamps: false # Never set timestamps automatically
    #
    # Because it relies on the index information from the database
    # <tt>:unique_by</tt> is recommended to be paired with
    # Active Record's schema_cache.
    #
    # ==== Example
    #
    #   # Insert records and skip inserting any duplicates.
    #   # Here "Eloquent Ruby" is skipped because its id is not unique.
    #
    #   Book.insert_all([
    #     { id: 1, title: "Rework", author: "David" },
    #     { id: 1, title: "Eloquent Ruby", author: "Russ" }
    #   ])
    #
    #   # insert_all works on chained scopes, and you can use create_with
    #   # to set default attributes for all inserted records.
    #
    #   author.books.create_with(created_at: Time.now).insert_all([
    #     { id: 1, title: "Rework" },
    #     { id: 2, title: "Eloquent Ruby" }
    #   ])
    def insert_all(attributes, returning: nil, unique_by: nil, record_timestamps: nil)
      InsertAll.execute(self, attributes, on_duplicate: :skip, returning: returning, unique_by: unique_by, record_timestamps: record_timestamps)
    end

    # Inserts a single record into the database in a single SQL INSERT
    # statement. It does not instantiate any models nor does it trigger
    # Active Record callbacks or validations. Though passed values
    # go through Active Record's type casting and serialization.
    #
    # See #insert_all! for more.
    def insert!(attributes, returning: nil, record_timestamps: nil)
      insert_all!([ attributes ], returning: returning, record_timestamps: record_timestamps)
    end

    # Inserts multiple records into the database in a single SQL INSERT
    # statement. It does not instantiate any models nor does it trigger
    # Active Record callbacks or validations. Though passed values
    # go through Active Record's type casting and serialization.
    #
    # The +attributes+ parameter is an Array of Hashes. Every Hash determines
    # the attributes for a single row and must have the same keys.
    #
    # Raises ActiveRecord::RecordNotUnique if any rows violate a
    # unique index on the table. In that case, no rows are inserted.
    #
    # To skip duplicate rows, see #insert_all. To replace them, see #upsert_all.
    #
    # Returns an ActiveRecord::Result with its contents based on
    # <tt>:returning</tt> (see below).
    #
    # ==== Options
    #
    # [:returning]
    #   (PostgreSQL, SQLite3, and MariaDB only) An array of attributes to return for all successfully
    #   inserted records, which by default is the primary key.
    #   Pass <tt>returning: %w[ id name ]</tt> for both id and name
    #   or <tt>returning: false</tt> to omit the underlying <tt>RETURNING</tt> SQL
    #   clause entirely.
    #
    #   You can also pass an SQL string if you need more control on the return values
    #   (for example, <tt>returning: Arel.sql("id, name as new_name")</tt>).
    #
    # [:record_timestamps]
    #   By default, automatic setting of timestamp columns is controlled by
    #   the model's <tt>record_timestamps</tt> config, matching typical
    #   behavior.
    #
    #   To override this and force automatic setting of timestamp columns one
    #   way or the other, pass <tt>:record_timestamps</tt>:
    #
    #     record_timestamps: true  # Always set timestamps automatically
    #     record_timestamps: false # Never set timestamps automatically
    #
    # ==== Examples
    #
    #   # Insert multiple records
    #   Book.insert_all!([
    #     { title: "Rework", author: "David" },
    #     { title: "Eloquent Ruby", author: "Russ" }
    #   ])
    #
    #   # Raises ActiveRecord::RecordNotUnique because "Eloquent Ruby"
    #   # does not have a unique id.
    #   Book.insert_all!([
    #     { id: 1, title: "Rework", author: "David" },
    #     { id: 1, title: "Eloquent Ruby", author: "Russ" }
    #   ])
    def insert_all!(attributes, returning: nil, record_timestamps: nil)
      InsertAll.execute(self, attributes, on_duplicate: :raise, returning: returning, record_timestamps: record_timestamps)
    end

    # Updates or inserts (upserts) a single record into the database in a
    # single SQL INSERT statement. It does not instantiate any models nor does
    # it trigger Active Record callbacks or validations. Though passed values
    # go through Active Record's type casting and serialization.
    #
    # See #upsert_all for documentation.
    def upsert(attributes, **kwargs)
      upsert_all([ attributes ], **kwargs)
    end

    # Updates or inserts (upserts) multiple records into the database in a
    # single SQL INSERT statement. It does not instantiate any models nor does
    # it trigger Active Record callbacks or validations. Though passed values
    # go through Active Record's type casting and serialization.
    #
    # The +attributes+ parameter is an Array of Hashes. Every Hash determines
    # the attributes for a single row and must have the same keys.
    #
    # Returns an ActiveRecord::Result with its contents based on
    # <tt>:returning</tt> (see below).
    #
    # By default, +upsert_all+ will update all the columns that can be updated when
    # there is a conflict. These are all the columns except primary keys, read-only
    # columns, and columns covered by the optional +unique_by+.
    #
    # ==== Options
    #
    # [:returning]
    #   (PostgreSQL, SQLite3, and MariaDB only) An array of attributes to return for all successfully
    #   upserted records, which by default is the primary key.
    #   Pass <tt>returning: %w[ id name ]</tt> for both id and name
    #   or <tt>returning: false</tt> to omit the underlying <tt>RETURNING</tt> SQL
    #   clause entirely.
    #
    #   You can also pass an SQL string if you need more control on the return values
    #   (for example, <tt>returning: Arel.sql("id, name as new_name")</tt>).
    #
    # [:unique_by]
    #   (PostgreSQL and SQLite only) By default rows are considered to be unique
    #   by every unique index on the table. Any duplicate rows are skipped.
    #
    #   To skip rows according to just one unique index pass <tt>:unique_by</tt>.
    #
    #   Consider a Book model where no duplicate ISBNs make sense, but if any
    #   row has an existing id, or is not unique by another unique index,
    #   ActiveRecord::RecordNotUnique is raised.
    #
    #   Unique indexes can be identified by columns or name:
    #
    #     unique_by: :isbn
    #     unique_by: %i[ author_id name ]
    #     unique_by: :index_books_on_isbn
    #
    # Because it relies on the index information from the database
    # <tt>:unique_by</tt> is recommended to be paired with
    # Active Record's schema_cache.
    #
    # [:on_duplicate]
    #   Configure the SQL update sentence that will be used in case of conflict.
    #
    #   NOTE: If you use this option you must provide all the columns you want to update
    #   by yourself.
    #
    #   Example:
    #
    #     Commodity.upsert_all(
    #       [
    #         { id: 2, name: "Copper", price: 4.84 },
    #         { id: 4, name: "Gold", price: 1380.87 },
    #         { id: 6, name: "Aluminium", price: 0.35 }
    #       ],
    #       on_duplicate: Arel.sql("price = GREATEST(commodities.price, EXCLUDED.price)")
    #     )
    #
    #   See the related +:update_only+ option. Both options can't be used at the same time.
    #
    # [:update_only]
    #   Provide a list of column names that will be updated in case of conflict. If not provided,
    #   +upsert_all+ will update all the columns that can be updated. These are all the columns
    #   except primary keys, read-only columns, and columns covered by the optional +unique_by+
    #
    #   Example:
    #
    #     Commodity.upsert_all(
    #       [
    #         { id: 2, name: "Copper", price: 4.84 },
    #         { id: 4, name: "Gold", price: 1380.87 },
    #         { id: 6, name: "Aluminium", price: 0.35 }
    #       ],
    #       update_only: [:price] # Only prices will be updated
    #     )
    #
    #   See the related +:on_duplicate+ option. Both options can't be used at the same time.
    #
    # [:record_timestamps]
    #   By default, automatic setting of timestamp columns is controlled by
    #   the model's <tt>record_timestamps</tt> config, matching typical
    #   behavior.
    #
    #   To override this and force automatic setting of timestamp columns one
    #   way or the other, pass <tt>:record_timestamps</tt>:
    #
    #     record_timestamps: true  # Always set timestamps automatically
    #     record_timestamps: false # Never set timestamps automatically
    #
    # ==== Examples
    #
    #   # Inserts multiple records, performing an upsert when records have duplicate ISBNs.
    #   # Here "Eloquent Ruby" overwrites "Rework" because its ISBN is duplicate.
    #
    #   Book.upsert_all([
    #     { title: "Rework", author: "David", isbn: "1" },
    #     { title: "Eloquent Ruby", author: "Russ", isbn: "1" }
    #   ], unique_by: :isbn)
    #
    #   Book.find_by(isbn: "1").title # => "Eloquent Ruby"
    def upsert_all(attributes, on_duplicate: :update, update_only: nil, returning: nil, unique_by: nil, record_timestamps: nil)
      InsertAll.execute(self, attributes, on_duplicate: on_duplicate, update_only: update_only, returning: returning, unique_by: unique_by, record_timestamps: record_timestamps)
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
        touch_updates = model.touch_attributes_with_time(*names, **options)
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
      update_all model.touch_attributes_with_time(*names, time: time)
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
      return 0 if @none

      invalid_methods = INVALID_METHODS_FOR_DELETE_ALL.select do |method|
        value = @values[method]
        method == :distinct ? value : value&.any?
      end
      if invalid_methods.any?
        raise ActiveRecordError.new("delete_all doesn't support #{invalid_methods.join(', ')}")
      end

      model.with_connection do |c|
        arel = eager_loading? ? apply_join_dependency.arel : build_arel(c)
        arel.source.left = table

        group_values_arel_columns = arel_columns(group_values.uniq)
        having_clause_ast = having_clause.ast unless having_clause.empty?
        key = if model.composite_primary_key?
          primary_key.map { |pk| table[pk] }
        else
          table[primary_key]
        end
        stmt = arel.compile_delete(key, having_clause_ast, group_values_arel_columns)

        c.delete(stmt, "#{model} Delete All").tap { reset }
      end
    end

    # Deletes the row with a primary key matching the +id+ argument, using an
    # SQL +DELETE+ statement, and returns the number of rows deleted. Active
    # Record objects are not instantiated, so the object's callbacks are not
    # executed, including any <tt>:dependent</tt> association options.
    #
    # You can delete multiple rows at once by passing an Array of <tt>id</tt>s.
    #
    # Note: Although it is often much faster than the alternative, #destroy,
    # skipping callbacks might bypass business logic in your application
    # that ensures referential integrity or performs other essential jobs.
    #
    # ==== Examples
    #
    #   # Delete a single row
    #   Todo.delete(1)
    #
    #   # Delete multiple rows
    #   Todo.delete([2,3,4])
    def delete(id_or_array)
      return 0 if id_or_array.nil? || (id_or_array.is_a?(Array) && id_or_array.empty?)

      where(model.primary_key => id_or_array).delete_all
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
    # * +id+ - This should be the id or an array of ids to be destroyed.
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
      multiple_ids = if model.composite_primary_key?
        id.first.is_a?(Array)
      else
        id.is_a?(Array)
      end

      if multiple_ids
        find(id).each(&:destroy)
      else
        find(id).destroy
      end
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
    #
    # When the +Relation+ is iterated, if the background query wasn't executed yet,
    # it will be performed by the foreground thread.
    #
    # Note that {config.active_record.async_query_executor}[https://guides.rubyonrails.org/configuring.html#config-active-record-async-query-executor] must be configured
    # for queries to actually be executed concurrently. Otherwise it defaults to
    # executing them in the foreground.
    #
    # If the query was actually executed in the background, the Active Record logs will show
    # it by prefixing the log line with <tt>ASYNC</tt>:
    #
    #   ASYNC Post Load (0.0ms) (db time 2ms)  SELECT "posts".* FROM "posts" LIMIT 100
    def load_async
      with_connection do |c|
        return load if !c.async_enabled?

        unless loaded?
          result = exec_main_query(async: !c.current_transaction.joinable?)

          if result.is_a?(Array)
            @records = result
          else
            @future_result = result
          end
          @loaded = true
        end
      end

      self
    end

    def then(&block) # :nodoc:
      if @future_result
        @future_result.then do
          yield self
        end
      else
        super
      end
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
      @delegate_to_model = false
      @to_sql = @arel = @loaded = @should_eager_load = nil
      @offsets = @take = nil
      @cache_keys = nil
      @cache_versions = nil
      @records = nil
      self
    end

    # Returns sql statement for the relation.
    #
    #   User.where(name: 'Oscar').to_sql
    #   # SELECT "users".* FROM "users"  WHERE "users"."name" = 'Oscar'
    def to_sql
      @to_sql ||= if eager_loading?
        apply_join_dependency do |relation, join_dependency|
          relation = join_dependency.apply_column_aliases(relation)
          relation.to_sql
        end
      else
        model.with_connection do |conn|
          conn.unprepared_statement { conn.to_sql(arel) }
        end
      end
    end

    # Returns a hash of where conditions.
    #
    #   User.where(name: 'Oscar').where_values_hash
    #   # => {name: "Oscar"}
    def where_values_hash(relation_table_name = model.table_name) # :nodoc:
      where_clause.to_h(relation_table_name)
    end

    def scope_for_create
      hash = where_clause.to_h(model.table_name, equality_only: true)
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
    # nested hashes which partially match, e.g. <tt>{ a: :b } & { a: [:b, :c] }</tt>
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

    def pretty_print(pp)
      subject = loaded? ? records : annotate("loading for pp")
      entries = subject.take([limit_value, 11].compact.min)

      entries[10] = "..." if entries.size == 11

      pp.pp(entries)
    end

    # Returns true if relation is blank.
    def blank?
      records.blank?
    end

    def readonly?
      readonly_value
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
      @values == model.unscoped.values
    end

    def has_limit_or_offset? # :nodoc:
      limit_value || offset_value
    end

    def alias_tracker(joins = [], aliases = nil) # :nodoc:
      ActiveRecord::Associations::AliasTracker.create(model.connection_pool, table.name, joins, aliases)
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

    private
      def already_in_scope?(registry)
        @delegate_to_model && registry.current_scope(model, true)
      end

      def global_scope?(registry)
        registry.global_current_scope(model, true)
      end

      def current_scope_restoring_block(&block)
        current_scope = model.current_scope(true)
        -> record do
          model.current_scope = current_scope
          yield record if block_given?
        end
      end

      def _new(attributes, &block)
        model.new(attributes, &block)
      end

      def _create(attributes, &block)
        model.create(attributes, &block)
      end

      def _create!(attributes, &block)
        model.create!(attributes, &block)
      end

      def _scoping(scope, registry, all_queries = false)
        previous = registry.current_scope(model, true)
        registry.set_current_scope(model, scope)

        if all_queries
          previous_global = registry.global_current_scope(model, true)
          registry.set_global_current_scope(model, scope)
        end
        yield
      ensure
        registry.set_current_scope(model, previous)
        if all_queries
          registry.set_global_current_scope(model, previous_global)
        end
      end

      def _substitute_values(values)
        values.map do |name, value|
          attr = table[name]
          if Arel.arel_node?(value)
            if value.is_a?(Arel::Nodes::SqlLiteral)
              value = Arel::Nodes::Grouping.new(value)
            end
          else
            type = model.type_for_attribute(attr.name)
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
          records.each { |record| record.strict_loading!(strict_loading_value) } unless strict_loading_value.nil?

          records
        end
      end

      def exec_main_query(async: false)
        if @none
          if async
            return FutureResult.wrap([])
          else
            return []
          end
        end

        skip_query_cache_if_necessary do
          if where_clause.contradiction?
            [].freeze
          elsif eager_loading?
            model.with_connection do |c|
              apply_join_dependency do |relation, join_dependency|
                if relation.null_relation?
                  [].freeze
                else
                  relation = join_dependency.apply_column_aliases(relation)
                  @_join_dependency = join_dependency
                  c.select_all(relation.arel, "SQL", async: async)
                end
              end
            end
          else
            model.with_connection do |c|
              model._query_by_sql(c, arel, async: async)
            end
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
          model._load_from_sql(rows, &block).freeze
        end
      end

      def skip_query_cache_if_necessary(&block)
        if skip_query_cache_value
          model.uncached(&block)
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
